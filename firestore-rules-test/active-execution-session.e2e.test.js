const assert = require("node:assert/strict");
const { deleteApp, initializeApp } = require("firebase/app");
const {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {
  Timestamp,
  collection,
  connectFirestoreEmulator,
  doc,
  deleteDoc,
  getCountFromServer,
  getDoc,
  getFirestore,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const {
  createSessionWithLock,
  releaseSessionLock,
} = require("./active-execution-session-test-helper");

const projectId = "demo-calmatea-local";
const childEmail = "child@calmatea.test";
const psychologistEmail = "psychologist@calmatea.test";
const password = "CalmaTEA-Local-Only-2026!";
const apps = [];

function emulatorAddress(name) {
  const value = process.env[name];
  if (!value || !/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(value)) {
    throw new Error(`${name} must point to a loopback emulator.`);
  }
  const separator = value.lastIndexOf(":");
  return {
    host: value.slice(0, separator).replace(/^\[|\]$/g, ""),
    port: Number(value.slice(separator + 1)),
  };
}

async function client(label, email, authAddress, firestoreAddress) {
  const app = initializeApp(
    { projectId, apiKey: "local-emulator-key" },
    `active-session-${label}-${Date.now()}`,
  );
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(
    auth,
    `http://${authAddress.host}:${authAddress.port}`,
    { disableWarnings: true },
  );
  const db = getFirestore(app);
  connectFirestoreEmulator(db, firestoreAddress.host, firestoreAddress.port);
  await signInWithEmailAndPassword(auth, email, password);
  return { auth, db };
}

async function startOrRecover(db, uid, activityId) {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const newSession = doc(collection(db, "sessions"));
    const decision = await runTransaction(db, async (transaction) => {
      const profile = await transaction.get(doc(db, "users", uid));
      const childId = profile.data().childId;
      const lockReference = doc(db, "activeExecutionSessions", childId);
      const lock = await transaction.get(lockReference);

      if (lock.exists()) {
        const current = await transaction.get(
          doc(db, "sessions", lock.data().sessionId),
        );
        assert.equal(current.exists(), true);
        assert.equal(current.data().childId, childId);
        if (current.data().status === "inProgress") {
          if (
            current.data().activityId === activityId &&
            current.data().childUserId === uid
          ) {
            return { sessionId: current.id, retry: false };
          }
          const error = new Error("ACTIVE_SESSION_CONFLICT");
          error.code = "active-session-conflict";
          error.sessionId = current.id;
          throw error;
        }

        transaction.delete(lockReference);
        return { retry: true };
      }

      const activity = await transaction.get(doc(db, "activities", activityId));
      const sessionData = {
        id: newSession.id,
        activityId,
        therapyId: activity.data().therapyId,
        childId,
        psychologistId: activity.data().psychologistId,
        childUserId: uid,
        status: "inProgress",
        startedAt: serverTimestamp(),
      };
      createSessionWithLock(transaction, db, newSession, sessionData);
      return { sessionId: newSession.id, retry: false };
    });
    if (!decision.retry) return decision.sessionId;
  }
  throw new Error("Unable to release stale lock");
}

async function interrupt(db, uid, sessionId) {
  await runTransaction(db, async (transaction) => {
    const sessionReference = doc(db, "sessions", sessionId);
    const session = await transaction.get(sessionReference);
    assert.equal(session.data().childUserId, uid);
    const lock = await transaction.get(
      doc(db, "activeExecutionSessions", session.data().childId),
    );
    if (session.data().status === "interrupted") {
      if (lock.exists() && lock.data().sessionId === sessionId) {
        releaseSessionLock(transaction, db, session.data().childId);
      }
      return;
    }
    assert.equal(session.data().status, "inProgress");
    assert.equal(lock.data().sessionId, sessionId);
    transaction.update(sessionReference, {
      status: "interrupted",
      endedAt: serverTimestamp(),
    });
    releaseSessionLock(transaction, db, session.data().childId);
  });
}

async function completeSequence(db, uid, sessionId, activityType = "sequence", metrics = { itemsCount: 2, checksCount: 1 }) {
  await runTransaction(db, async (transaction) => {
    const sessionReference = doc(db, "sessions", sessionId);
    const resultReference = doc(db, "activityResults", sessionId);
    const session = await transaction.get(sessionReference);
    const lock = await transaction.get(
      doc(db, "activeExecutionSessions", session.data().childId),
    );
    if (session.data().status === "completed") {
      const result = await transaction.get(resultReference);
      assert.equal(result.exists(), true);
      assert.equal(result.data().id, sessionId);
      assert.equal(result.data().activityType, activityType);
      if (lock.exists() && lock.data().sessionId === sessionId) {
        releaseSessionLock(transaction, db, session.data().childId);
      }
      return;
    }
    assert.equal(session.data().status, "inProgress");
    assert.equal(lock.data().sessionId, sessionId);
    transaction.update(sessionReference, {
      status: "completed",
      endedAt: serverTimestamp(),
    });
    transaction.set(resultReference, {
      id: sessionId,
      activityId: session.data().activityId,
      therapyId: session.data().therapyId,
      childId: session.data().childId,
      psychologistId: session.data().psychologistId,
      childUserId: uid,
      activityType,
      completedAt: serverTimestamp(),
      metrics,
      schemaVersion: 1,
    });
    releaseSessionLock(transaction, db, session.data().childId);
  });
}

describe("active execution session recovery and concurrency", () => {
  let childA;
  let childB;
  let psychologist;
  let testEnv;

  before(async () => {
    if (process.env.GCLOUD_PROJECT !== projectId) {
      throw new Error(`GCLOUD_PROJECT must be exactly ${projectId}.`);
    }
    const authAddress = emulatorAddress("FIREBASE_AUTH_EMULATOR_HOST");
    const firestoreAddress = emulatorAddress("FIRESTORE_EMULATOR_HOST");
    childA = await client("child-a", childEmail, authAddress, firestoreAddress);
    childB = await client("child-b", childEmail, authAddress, firestoreAddress);
    psychologist = await client(
      "psychologist",
      psychologistEmail,
      authAddress,
      firestoreAddress,
    );
    testEnv = await initializeTestEnvironment({ projectId });
  });

  after(async () => {
    for (const item of [childA, childB, psychologist]) {
      if (item?.auth.currentUser) await signOut(item.auth);
    }
    await Promise.all(apps.map((app) => deleteApp(app)));
    await testEnv.cleanup();
  });

  it("recovers, serializes devices, resolves conflicts and retries idempotently", async () => {
    const uid = childA.auth.currentUser.uid;

    const first = await startOrRecover(childA.db, uid, "activity-sequence");
    const reopened = await startOrRecover(childB.db, uid, "activity-sequence");
    assert.equal(reopened, first);

    await assert.rejects(
      startOrRecover(childB.db, uid, "activity-matching"),
      (error) => error.code === "active-session-conflict",
    );
    const lockBeforeConfirmation = await getDoc(
      doc(childA.db, "activeExecutionSessions", "child-local-a"),
    );
    assert.equal(lockBeforeConfirmation.data().sessionId, first);

    await interrupt(childA.db, uid, first);
    await interrupt(childB.db, uid, first);
    const next = await startOrRecover(childB.db, uid, "activity-matching");
    assert.notEqual(next, first);
    await interrupt(childB.db, uid, next);

    const simultaneous = await Promise.all([
      startOrRecover(childA.db, uid, "activity-sequence"),
      startOrRecover(childB.db, uid, "activity-sequence"),
    ]);
    assert.equal(simultaneous[0], simultaneous[1]);
    await completeSequence(childA.db, uid, simultaneous[0]);
    await completeSequence(childB.db, uid, simultaneous[0]);

    const completedResult = await getDoc(
      doc(childA.db, "activityResults", simultaneous[0]),
    );
    assert.equal(completedResult.exists(), true);
    const releasedLock = await getDoc(
      doc(childA.db, "activeExecutionSessions", "child-local-a"),
    );
    assert.equal(releasedLock.exists(), false);

    const staleStartedAt = Timestamp.fromDate(
      new Date("2026-10-08T16:00:00Z"),
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await Promise.all([
        setDoc(doc(adminDb, "sessions", "stale-terminal"), {
          id: "stale-terminal",
          activityId: "activity-sequence",
          therapyId: "therapy-local-a",
          childId: "child-local-a",
          psychologistId: completedResult.data().psychologistId,
          childUserId: uid,
          status: "interrupted",
          startedAt: staleStartedAt,
          endedAt: staleStartedAt,
        }),
        setDoc(
          doc(adminDb, "activeExecutionSessions", "child-local-a"),
          {
            sessionId: "stale-terminal",
            activityId: "activity-sequence",
            childId: "child-local-a",
            psychologistId: completedResult.data().psychologistId,
            childUserId: uid,
            startedAt: staleStartedAt,
          },
        ),
      ]);
    });

    const recoveredAfterRestart = await startOrRecover(
      childA.db,
      uid,
      "activity-sequence",
    );
    assert.notEqual(recoveredAfterRestart, "stale-terminal");

    await assert.rejects(
      getDoc(
        doc(
          psychologist.db,
          "activeExecutionSessions",
          "child-local-a",
        ),
      ),
    );
    await completeSequence(childA.db, uid, recoveredAfterRestart);

    const psychologistId = completedResult.data().psychologistId;
    const total = await getCountFromServer(
      query(
        collection(psychologist.db, "sessions"),
        where("psychologistId", "==", psychologistId),
      ),
    );
    const completed = await getCountFromServer(
      query(
        collection(psychologist.db, "sessions"),
        where("psychologistId", "==", psychologistId),
        where("status", "==", "completed"),
      ),
    );
    assert.equal(total.data().count >= 5, true);
    assert.equal(completed.data().count >= 2, true);
  });

  const engines = [
    ["sequence", "activity-sequence", { itemsCount: 2, checksCount: 1 }],
    ["matching", "activity-matching", { relationsCompleted: 2, checksCount: 1 }],
    ["motor", "activity-motor", { stepsVisited: 2 }],
    ["emotion", "activity-emotion", { exercisesReviewed: 2 }],
    ["dragDrop", "activity-drag-drop", { itemsPlaced: 2, checksCount: 1 }],
    ["pictogram", "activity-pictogram", { interactionsCount: 2 }],
    ["tracing", "activity-tracing", { practiceCompleted: true, strokesCount: 1 }],
    ["timer", "activity-timer", { configuredDurationSeconds: 5, elapsedSeconds: 5 }],
  ];
  for (const status of ["completed", "cancelled"]) {
    for (const [type, activityId, metrics] of engines) {
      it(`${type} closes and retries after professional status ${status}`, async () => {
        const activityReference = doc(psychologist.db, "activities", activityId);
        await updateDoc(activityReference, { status: "assigned" });
        const uid = childA.auth.currentUser.uid;
        const sessionId = await startOrRecover(childA.db, uid, activityId);
        // No check-then-delete race: every persisted activity is retained.
        await assert.rejects(deleteDoc(activityReference), (error) => error.code === "permission-denied");
        await assert.rejects(updateDoc(activityReference, { type: type === "timer" ? "sequence" : "timer", configuration: {} }), (error) => error.code === "permission-denied");
        await updateDoc(activityReference, { status });
        await assert.rejects(getDoc(doc(childA.db, "activities", activityId)), (error) => error.code === "permission-denied");
        // Recovery of the existing session is not a new execution.
        assert.equal(await startOrRecover(childB.db, uid, activityId), sessionId);
        await completeSequence(childA.db, uid, sessionId, type, metrics);
        await completeSequence(childB.db, uid, sessionId, type, metrics);
        assert.equal((await getDoc(doc(childA.db, "activeExecutionSessions", "child-local-a"))).exists(), false);
        await assert.rejects(startOrRecover(childA.db, uid, activityId), (error) => error.code === "permission-denied");
        const saved = await getDoc(doc(psychologist.db, "activityResults", sessionId));
        assert.equal(saved.data().activityType, type);
        await assert.rejects(deleteDoc(activityReference), (error) => error.code === "permission-denied");
        assert.equal((await getDoc(activityReference)).data().type, type);
        const matchingResults = await getCountFromServer(query(
          collection(psychologist.db, "activityResults"),
          where("psychologistId", "==", psychologist.auth.currentUser.uid),
          where("id", "==", sessionId),
        ));
        assert.equal(matchingResults.data().count, 1);
        await assert.rejects(setDoc(doc(childA.db, "activityResults", sessionId), saved.data()), (error) => error.code === "permission-denied");
      });
    }
  }
});
