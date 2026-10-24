const assert = require("node:assert/strict");
const { deleteApp, initializeApp } = require("firebase/app");
const {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} = require("firebase/auth");
const {
  collection,
  connectFirestoreEmulator,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  where,
} = require("firebase/firestore");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

const projectId = "demo-calmatea-local";
const password = "CalmaTEA-Phase10-Local-Only-2026!";
const emails = {
  child: "phase10-child@calmatea.test",
  psychA: "phase10-psych-a@calmatea.test",
  psychB: "phase10-psych-b@calmatea.test",
};
const apps = [];

function address(name) {
  const value = process.env[name];
  if (!value || !/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(value)) {
    throw new Error(`${name} must point to a loopback emulator.`);
  }
  const separator = value.lastIndexOf(":");
  return {
    host: value.slice(0, separator).replace(/^\[|\]$/g, ""),
    port: Number(value.slice(separator + 1)),
    raw: value,
  };
}

async function resetAuth(authAddress) {
  const response = await fetch(
    `http://${authAddress.raw}/emulator/v1/projects/${projectId}/accounts`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true);
}

async function createAuthUser(authAddress, email) {
  const response = await fetch(
    `http://${authAddress.raw}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const payload = await response.json();
  assert.equal(response.ok, true, `Unable to create ${email}`);
  return payload.localId;
}

async function client(label, email, authAddress, firestoreAddress) {
  const app = initializeApp(
    { projectId, apiKey: "local-key" },
    `phase10-${label}-${Date.now()}`,
  );
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authAddress.raw}`, {
    disableWarnings: true,
  });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, firestoreAddress.host, firestoreAddress.port);
  await signInWithEmailAndPassword(auth, email, password);
  return { auth, db };
}

async function startSession(db, uid, activityId) {
  const sessionReference = doc(collection(db, "sessions"));
  await runTransaction(db, async (transaction) => {
    const profile = await transaction.get(doc(db, "users", uid));
    const activity = await transaction.get(doc(db, "activities", activityId));
    transaction.set(sessionReference, {
      id: sessionReference.id,
      activityId,
      therapyId: activity.data().therapyId,
      childId: profile.data().childId,
      psychologistId: activity.data().psychologistId,
      childUserId: uid,
      status: "inProgress",
      startedAt: serverTimestamp(),
    });
  });
  return sessionReference.id;
}

async function completeSequence(db, uid, sessionId) {
  const sessionReference = doc(db, "sessions", sessionId);
  await runTransaction(db, async (transaction) => {
    const session = await transaction.get(sessionReference);
    transaction.update(sessionReference, {
      status: "completed",
      endedAt: serverTimestamp(),
    });
    transaction.set(doc(db, "activityResults", sessionId), {
      id: sessionId,
      activityId: session.data().activityId,
      therapyId: session.data().therapyId,
      childId: session.data().childId,
      psychologistId: session.data().psychologistId,
      childUserId: uid,
      activityType: "sequence",
      completedAt: serverTimestamp(),
      metrics: { itemsCount: 3, checksCount: 2 },
      schemaVersion: 1,
    });
  });
}

async function executionCounts(db, psychologistId) {
  const owned = query(
    collection(db, "sessions"),
    where("psychologistId", "==", psychologistId),
  );
  const snapshots = await Promise.all([
    getCountFromServer(owned),
    getCountFromServer(query(owned, where("status", "==", "completed"))),
    getCountFromServer(query(owned, where("status", "==", "interrupted"))),
    getCountFromServer(query(owned, where("status", "==", "inProgress"))),
  ]);
  return snapshots.map((snapshot) => snapshot.data().count);
}

describe("Phase 10 integral flow against local Firebase emulators", () => {
  let testEnv;
  let authAddress;
  let firestoreAddress;
  let ids;

  before(async () => {
    if (process.env.GCLOUD_PROJECT !== projectId) {
      throw new Error(`GCLOUD_PROJECT must be exactly ${projectId}.`);
    }
    authAddress = address("FIREBASE_AUTH_EMULATOR_HOST");
    firestoreAddress = address("FIRESTORE_EMULATOR_HOST");
    await resetAuth(authAddress);
    ids = {};
    for (const [name, email] of Object.entries(emails)) {
      ids[name] = await createAuthUser(authAddress, email);
    }

    testEnv = await initializeTestEnvironment({ projectId });
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const createdAt = new Date("2026-10-13T12:00:00Z");
      await Promise.all([
        setDoc(doc(db, "users", ids.child), {
          id: ids.child,
          name: "Child Phase 10",
          email: emails.child,
          role: "child",
          childId: "phase10-child",
          createdAt,
        }),
        ...["psychA", "psychB"].map((name) =>
          setDoc(doc(db, "users", ids[name]), {
            id: ids[name],
            name,
            email: emails[name],
            role: "psychologist",
            createdAt,
          }),
        ),
        setDoc(doc(db, "children", "phase10-child"), {
          psychologistId: ids.psychA,
          fullName: "Child Phase 10",
        }),
        setDoc(doc(db, "therapies", "phase10-therapy"), {
          childId: "phase10-child",
          psychologistId: ids.psychA,
        }),
        setDoc(doc(db, "activities", "phase10-sequence"), {
          therapyId: "phase10-therapy",
          childId: "phase10-child",
          psychologistId: ids.psychA,
          title: "Sequence Phase 10",
          description: "",
          type: "sequence",
          difficulty: 1,
          instructions: "Ordena los pasos",
          configuration: { items: ["uno", "dos", "tres"] },
          status: "assigned",
          createdAt,
          updatedAt: createdAt,
        }),
      ]);
    });
  });

  after(async () => {
    for (const app of apps) {
      const auth = getAuth(app);
      if (auth.currentUser) await signOut(auth);
      await deleteApp(app);
    }
    if (testEnv) await testEnv.cleanup();
  });

  it("connects child completion with owner history and dashboard counts", async () => {
    const child = await client(
      "child",
      emails.child,
      authAddress,
      firestoreAddress,
    );
    const psychA = await client(
      "psych-a",
      emails.psychA,
      authAddress,
      firestoreAddress,
    );
    const psychB = await client(
      "psych-b",
      emails.psychB,
      authAddress,
      firestoreAddress,
    );

    const sessionId = await startSession(
      child.db,
      ids.child,
      "phase10-sequence",
    );
    await completeSequence(child.db, ids.child, sessionId);

    const session = await getDoc(doc(child.db, "sessions", sessionId));
    const result = await getDoc(doc(child.db, "activityResults", sessionId));
    assert.equal(session.id, result.id);
    assert.equal(session.data().status, "completed");
    assert.equal(result.data().schemaVersion, 1);
    assert.deepEqual(result.data().metrics, {
      itemsCount: 3,
      checksCount: 2,
    });
    assert.equal("answer" in result.data(), false);
    assert.equal("coordinates" in result.data(), false);

    const history = await getDocs(
      query(
        collection(psychA.db, "sessions"),
        where("psychologistId", "==", ids.psychA),
        where("childId", "==", "phase10-child"),
        orderBy("startedAt", "desc"),
        limit(20),
      ),
    );
    assert.equal(history.size, 1);
    assert.equal(history.docs[0].id, sessionId);
    assert.equal(
      (await getDoc(doc(psychA.db, "activityResults", sessionId))).exists(),
      true,
    );
    assert.deepEqual(await executionCounts(psychA.db, ids.psychA), [1, 1, 0, 0]);

    await assert.rejects(getDoc(doc(psychB.db, "sessions", sessionId)));
    await assert.rejects(
      getDoc(doc(psychB.db, "activityResults", sessionId)),
    );
    await assert.rejects(executionCounts(psychB.db, ids.psychA));

    const totalBeforeConcurrentStart = (
      await getCountFromServer(
        query(
          collection(psychA.db, "sessions"),
          where("psychologistId", "==", ids.psychA),
        ),
      )
    ).data().count;
    await startSession(child.db, ids.child, "phase10-sequence");
    const statusCountsAfterStart = await executionCounts(
      psychA.db,
      ids.psychA,
    );
    assert.equal(totalBeforeConcurrentStart, 1);
    assert.deepEqual(statusCountsAfterStart, [2, 1, 0, 1]);
    assert.notEqual(
      totalBeforeConcurrentStart,
      statusCountsAfterStart.slice(1).reduce((sum, value) => sum + value, 0),
    );

    const activity = await getDoc(
      doc(child.db, "activities", "phase10-sequence"),
    );
    assert.equal(activity.data().status, "assigned");
  });
});
