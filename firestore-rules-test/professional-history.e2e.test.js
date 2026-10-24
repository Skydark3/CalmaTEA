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
  getDoc,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
  setDoc,
  where,
} = require("firebase/firestore");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

const projectId = "demo-calmatea-local";
const localPassword = "CalmaTEA-History-Local-Only-2026!";
const accounts = {
  psychA: "history-psych-a@calmatea.test",
  psychB: "history-psych-b@calmatea.test",
  childA: "history-child-a@calmatea.test",
  childB: "history-child-b@calmatea.test",
};
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
    raw: value,
  };
}

async function resetAuth(authAddress) {
  const response = await fetch(
    `http://${authAddress.raw}/emulator/v1/projects/${projectId}/accounts`,
    { method: "DELETE" },
  );
  assert.equal(response.ok, true, `Auth reset failed: ${response.status}`);
}

async function createAuthUser(authAddress, email) {
  const response = await fetch(
    `http://${authAddress.raw}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password: localPassword, returnSecureToken: true }),
    },
  );
  const payload = await response.json();
  assert.equal(response.ok, true, `Auth creation failed for ${email}`);
  return payload.localId;
}

async function authenticatedClient(label, email, authAddress, firestoreAddress) {
  const app = initializeApp(
    { projectId, apiKey: "local-key" },
    `history-${label}-${Date.now()}`,
  );
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authAddress.raw}`, {
    disableWarnings: true,
  });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, firestoreAddress.host, firestoreAddress.port);
  await signInWithEmailAndPassword(auth, email, localPassword);
  return { auth, db };
}

function session({ id, activityId, childId, psychologistId, childUserId, status, startedAt }) {
  return {
    id,
    activityId,
    therapyId: `therapy-${childId}`,
    childId,
    psychologistId,
    childUserId,
    status,
    startedAt: Timestamp.fromDate(startedAt),
    ...(status === "inProgress"
      ? {}
      : { endedAt: Timestamp.fromDate(new Date(startedAt.getTime() + 60000)) }),
  };
}

function result({ sessionData, activityType, metrics }) {
  return {
    id: sessionData.id,
    activityId: sessionData.activityId,
    therapyId: sessionData.therapyId,
    childId: sessionData.childId,
    psychologistId: sessionData.psychologistId,
    childUserId: sessionData.childUserId,
    activityType,
    completedAt: sessionData.endedAt,
    metrics,
    schemaVersion: 1,
  };
}

describe("professional activity history against Auth and Firestore emulators", () => {
  let testEnv;
  let ids;
  let authAddress;
  let firestoreAddress;

  before(async () => {
    if (process.env.GCLOUD_PROJECT !== projectId) {
      throw new Error(`GCLOUD_PROJECT must be exactly ${projectId}.`);
    }
    authAddress = emulatorAddress("FIREBASE_AUTH_EMULATOR_HOST");
    firestoreAddress = emulatorAddress("FIRESTORE_EMULATOR_HOST");
    await resetAuth(authAddress);
    ids = {
      psychA: await createAuthUser(authAddress, accounts.psychA),
      psychB: await createAuthUser(authAddress, accounts.psychB),
      childA: await createAuthUser(authAddress, accounts.childA),
      childB: await createAuthUser(authAddress, accounts.childB),
    };

    testEnv = await initializeTestEnvironment({ projectId });
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const createdAt = new Date("2026-10-12T12:00:00Z");
      await Promise.all([
        setDoc(doc(db, "users", ids.psychA), {
          id: ids.psychA,
          name: "Psychologist A",
          email: accounts.psychA,
          role: "psychologist",
          createdAt,
        }),
        setDoc(doc(db, "users", ids.psychB), {
          id: ids.psychB,
          name: "Psychologist B",
          email: accounts.psychB,
          role: "psychologist",
          createdAt,
        }),
        setDoc(doc(db, "users", ids.childA), {
          id: ids.childA,
          name: "Child A",
          email: accounts.childA,
          role: "child",
          childId: "history-child-a",
          createdAt,
        }),
        setDoc(doc(db, "users", ids.childB), {
          id: ids.childB,
          name: "Child B",
          email: accounts.childB,
          role: "child",
          childId: "history-child-b",
          createdAt,
        }),
        setDoc(doc(db, "children", "history-child-a"), {
          psychologistId: ids.psychA,
          fullName: "Child A",
        }),
        setDoc(doc(db, "children", "history-child-b"), {
          psychologistId: ids.psychB,
          fullName: "Child B",
        }),
      ]);

      const sessionACompleted = session({
        id: "history-a-completed",
        activityId: "history-activity-a-sequence",
        childId: "history-child-a",
        psychologistId: ids.psychA,
        childUserId: ids.childA,
        status: "completed",
        startedAt: new Date("2026-10-12T15:00:00Z"),
      });
      const sessionAInterrupted = session({
        id: "history-a-interrupted",
        activityId: "history-activity-a-emotion",
        childId: "history-child-a",
        psychologistId: ids.psychA,
        childUserId: ids.childA,
        status: "interrupted",
        startedAt: new Date("2026-10-12T16:00:00Z"),
      });
      const sessionAProgress = session({
        id: "history-a-progress",
        activityId: "history-activity-a-timer",
        childId: "history-child-a",
        psychologistId: ids.psychA,
        childUserId: ids.childA,
        status: "inProgress",
        startedAt: new Date("2026-10-12T17:00:00Z"),
      });
      const sessionBCompleted = session({
        id: "history-b-completed",
        activityId: "history-activity-b-motor",
        childId: "history-child-b",
        psychologistId: ids.psychB,
        childUserId: ids.childB,
        status: "completed",
        startedAt: new Date("2026-10-12T18:00:00Z"),
      });

      await Promise.all([
        setDoc(doc(db, "sessions", sessionACompleted.id), sessionACompleted),
        setDoc(doc(db, "sessions", sessionAInterrupted.id), sessionAInterrupted),
        setDoc(doc(db, "sessions", sessionAProgress.id), sessionAProgress),
        setDoc(doc(db, "sessions", sessionBCompleted.id), sessionBCompleted),
        setDoc(
          doc(db, "activityResults", sessionACompleted.id),
          result({
            sessionData: sessionACompleted,
            activityType: "sequence",
            metrics: { itemsCount: 3, checksCount: 2 },
          }),
        ),
        setDoc(
          doc(db, "activityResults", sessionBCompleted.id),
          result({
            sessionData: sessionBCompleted,
            activityType: "motor",
            metrics: { stepsVisited: 4 },
          }),
        ),
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

  it("enforces ownership, bounded ordering and session-result integrity", async () => {
    const psychA = await authenticatedClient(
      "psych-a",
      accounts.psychA,
      authAddress,
      firestoreAddress,
    );
    const psychB = await authenticatedClient(
      "psych-b",
      accounts.psychB,
      authAddress,
      firestoreAddress,
    );
    const childA = await authenticatedClient(
      "child-a",
      accounts.childA,
      authAddress,
      firestoreAddress,
    );

    const historyA = await getDocs(
      query(
        collection(psychA.db, "sessions"),
        where("psychologistId", "==", ids.psychA),
        where("childId", "==", "history-child-a"),
        orderBy("startedAt", "desc"),
        limit(2),
      ),
    );
    assert.equal(historyA.size, 2);
    assert.deepEqual(
      historyA.docs.map((item) => item.id),
      ["history-a-progress", "history-a-interrupted"],
    );

    const ownResult = await getDoc(
      doc(psychA.db, "activityResults", "history-a-completed"),
    );
    assert.equal(ownResult.exists(), true);
    assert.equal(ownResult.id, ownResult.data().id);
    assert.equal(ownResult.data().childId, "history-child-a");
    assert.equal(ownResult.data().psychologistId, ids.psychA);

    await assert.rejects(
      getDoc(doc(psychA.db, "sessions", "history-b-completed")),
    );
    await assert.rejects(
      getDoc(doc(psychB.db, "activityResults", "history-a-completed")),
    );
    await assert.rejects(
      getDocs(
        query(
          collection(childA.db, "sessions"),
          where("psychologistId", "==", ids.psychB),
          where("childId", "==", "history-child-b"),
          orderBy("startedAt", "desc"),
          limit(20),
        ),
      ),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const interruptedResult = await getDoc(
        doc(context.firestore(), "activityResults", "history-a-interrupted"),
      );
      assert.equal(interruptedResult.exists(), false);
    });
    assert.deepEqual(ownResult.data().metrics, {
      itemsCount: 3,
      checksCount: 2,
    });
  });
});
