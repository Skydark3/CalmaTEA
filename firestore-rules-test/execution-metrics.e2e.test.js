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
  getCountFromServer,
  getDocs,
  getFirestore,
  query,
  setDoc,
  where,
} = require("firebase/firestore");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

const projectId = "demo-calmatea-local";
const password = "CalmaTEA-Metrics-Local-Only-2026!";
const emails = {
  psychA: "metrics-psych-a@calmatea.test",
  psychB: "metrics-psych-b@calmatea.test",
  psychEmpty: "metrics-psych-empty@calmatea.test",
  childA: "metrics-child-a@calmatea.test",
  childB: "metrics-child-b@calmatea.test",
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
    `metrics-${label}-${Date.now()}`,
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

function session({ id, psychologistId, childId, childUserId, status, minute }) {
  const startedAt = new Date(`2026-10-12T15:${String(minute).padStart(2, "0")}:00Z`);
  return {
    id,
    activityId: `activity-${id}`,
    therapyId: `therapy-${childId}`,
    psychologistId,
    childId,
    childUserId,
    status,
    startedAt: Timestamp.fromDate(startedAt),
    ...(status === "inProgress"
      ? {}
      : { endedAt: Timestamp.fromDate(new Date(startedAt.getTime() + 60000)) }),
  };
}

async function executionCounts(db, psychologistId) {
  const owned = query(
    collection(db, "sessions"),
    where("psychologistId", "==", psychologistId),
  );
  const [total, completed, interrupted, inProgress] = await Promise.all([
    getCountFromServer(owned),
    getCountFromServer(
      query(owned, where("status", "==", "completed")),
    ),
    getCountFromServer(
      query(owned, where("status", "==", "interrupted")),
    ),
    getCountFromServer(
      query(owned, where("status", "==", "inProgress")),
    ),
  ]);
  return [
    total.data().count,
    completed.data().count,
    interrupted.data().count,
    inProgress.data().count,
  ];
}

describe("professional execution metrics against Auth and Firestore emulators", () => {
  let testEnv;
  let ids;
  let authAddress;
  let firestoreAddress;

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
      const createdAt = new Date("2026-10-12T12:00:00Z");
      await Promise.all([
        ...["psychA", "psychB", "psychEmpty"].map((name) =>
          setDoc(doc(db, "users", ids[name]), {
            id: ids[name],
            name,
            email: emails[name],
            role: "psychologist",
            createdAt,
          }),
        ),
        setDoc(doc(db, "users", ids.childA), {
          id: ids.childA,
          name: "Child A",
          email: emails.childA,
          role: "child",
          childId: "metrics-child-a",
          createdAt,
        }),
        setDoc(doc(db, "users", ids.childB), {
          id: ids.childB,
          name: "Child B",
          email: emails.childB,
          role: "child",
          childId: "metrics-child-b",
          createdAt,
        }),
        setDoc(doc(db, "children", "metrics-child-a"), {
          psychologistId: ids.psychA,
          fullName: "Child A",
        }),
        setDoc(doc(db, "children", "metrics-child-b"), {
          psychologistId: ids.psychB,
          fullName: "Child B",
        }),
      ]);

      const sessions = [
        session({ id: "a-completed", psychologistId: ids.psychA, childId: "metrics-child-a", childUserId: ids.childA, status: "completed", minute: 1 }),
        session({ id: "a-interrupted", psychologistId: ids.psychA, childId: "metrics-child-a", childUserId: ids.childA, status: "interrupted", minute: 2 }),
        session({ id: "a-progress", psychologistId: ids.psychA, childId: "metrics-child-a", childUserId: ids.childA, status: "inProgress", minute: 3 }),
        session({ id: "b-completed", psychologistId: ids.psychB, childId: "metrics-child-b", childUserId: ids.childB, status: "completed", minute: 4 }),
        session({ id: "b-interrupted", psychologistId: ids.psychB, childId: "metrics-child-b", childUserId: ids.childB, status: "interrupted", minute: 5 }),
      ];
      await Promise.all(
        sessions.map((item) => setDoc(doc(db, "sessions", item.id), item)),
      );
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

  it("returns isolated counts and denies child-wide aggregation", async () => {
    const psychA = await client("psych-a", emails.psychA, authAddress, firestoreAddress);
    const psychB = await client("psych-b", emails.psychB, authAddress, firestoreAddress);
    const psychEmpty = await client("psych-empty", emails.psychEmpty, authAddress, firestoreAddress);
    const childA = await client("child-a", emails.childA, authAddress, firestoreAddress);

    assert.deepEqual(await executionCounts(psychA.db, ids.psychA), [3, 1, 1, 1]);
    assert.deepEqual(await executionCounts(psychB.db, ids.psychB), [2, 1, 1, 0]);
    assert.deepEqual(await executionCounts(psychEmpty.db, ids.psychEmpty), [0, 0, 0, 0]);
    await assert.rejects(executionCounts(psychA.db, ids.psychB));
    await assert.rejects(executionCounts(childA.db, ids.psychA));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      assert.equal((await getDocs(collection(db, "sessions"))).size, 5);
      assert.equal((await getDocs(collection(db, "activityResults"))).size, 0);
    });
  });
});
