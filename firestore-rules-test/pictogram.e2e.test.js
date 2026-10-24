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
  getDoc,
  getDocs,
  getFirestore,
  query,
  runTransaction,
  serverTimestamp,
  where,
} = require("firebase/firestore");

const projectId = "demo-calmatea-local";
const childEmail = "child@calmatea.test";
const localPassword = "CalmaTEA-Local-Only-2026!";
let app;
let auth;
let db;

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

before(async () => {
  if (process.env.GCLOUD_PROJECT !== projectId) {
    throw new Error(`GCLOUD_PROJECT must be exactly ${projectId}.`);
  }
  const authAddress = emulatorAddress("FIREBASE_AUTH_EMULATOR_HOST");
  const firestoreAddress = emulatorAddress("FIRESTORE_EMULATOR_HOST");

  app = initializeApp({ projectId, apiKey: "local-emulator-key" });
  auth = getAuth(app);
  db = getFirestore(app);
  connectAuthEmulator(
    auth,
    `http://${authAddress.host}:${authAddress.port}`,
    { disableWarnings: true },
  );
  connectFirestoreEmulator(
    db,
    firestoreAddress.host,
    firestoreAddress.port,
  );
  await signInWithEmailAndPassword(auth, childEmail, localPassword);
});

after(async () => {
  if (auth?.currentUser) await signOut(auth);
  if (app) await deleteApp(app);
});

async function startPictogramSession(activityId) {
  const sessionReference = doc(collection(db, "sessions"));
  const uid = auth.currentUser.uid;

  await runTransaction(db, async (transaction) => {
    const profile = await transaction.get(doc(db, "users", uid));
    const activity = await transaction.get(doc(db, "activities", activityId));
    assert.equal(profile.data().role, "child");
    assert.equal(activity.data().childId, profile.data().childId);
    assert.equal(activity.data().type, "pictogram");

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

async function completePictogramSession(sessionId, interactionsCount) {
  const sessionReference = doc(db, "sessions", sessionId);
  const resultReference = doc(db, "activityResults", sessionId);
  const uid = auth.currentUser.uid;

  await runTransaction(db, async (transaction) => {
    const session = await transaction.get(sessionReference);
    const activity = await transaction.get(
      doc(db, "activities", session.data().activityId),
    );
    assert.equal(session.data().status, "inProgress");
    assert.equal(activity.data().type, "pictogram");

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
      activityType: activity.data().type,
      completedAt: serverTimestamp(),
      metrics: { interactionsCount },
      schemaVersion: 1,
    });
  });
}

async function interruptPictogramSession(sessionId) {
  const sessionReference = doc(db, "sessions", sessionId);
  await runTransaction(db, async (transaction) => {
    const session = await transaction.get(sessionReference);
    assert.equal(session.data().status, "inProgress");
    transaction.update(sessionReference, {
      status: "interrupted",
      endedAt: serverTimestamp(),
    });
  });
}

describe("Pictogram persistence against local Firebase emulators", () => {
  it("persists only aggregate metrics across completed and interrupted runs", async () => {
    const activityId = "activity-pictogram";
    const selectedOptionId = "pictogram-water";
    const selectedOptionLabel = "Agua";
    const activityBefore = await getDoc(doc(db, "activities", activityId));
    assert.equal(activityBefore.data().status, "assigned");

    const firstSessionId = await startPictogramSession(activityId);
    await completePictogramSession(firstSessionId, 2);

    const firstSession = await getDoc(doc(db, "sessions", firstSessionId));
    const firstResult = await getDoc(
      doc(db, "activityResults", firstSessionId),
    );
    assert.equal(firstSession.data().status, "completed");
    assert.equal(firstResult.id, firstSession.id);
    assert.deepEqual(firstResult.data().metrics, { interactionsCount: 2 });
    assert.deepEqual(Object.keys(firstResult.data().metrics), [
      "interactionsCount",
    ]);
    const serializedResult = JSON.stringify(firstResult.data());
    assert.equal(serializedResult.includes(selectedOptionId), false);
    assert.equal(serializedResult.includes(selectedOptionLabel), false);
    for (const forbidden of [
      "selectedOption",
      "selectionHistory",
      "emotion",
      "diagnosis",
      "clinical",
    ]) {
      assert.equal(serializedResult.includes(forbidden), false);
    }

    const secondSessionId = await startPictogramSession(activityId);
    await completePictogramSession(secondSessionId, 1);
    assert.notEqual(secondSessionId, firstSessionId);

    const interruptedSessionId = await startPictogramSession(activityId);
    await interruptPictogramSession(interruptedSessionId);
    const interruptedSession = await getDoc(
      doc(db, "sessions", interruptedSessionId),
    );
    assert.equal(interruptedSession.data().status, "interrupted");

    const uid = auth.currentUser.uid;
    const childId = interruptedSession.data().childId;
    const ownResults = await getDocs(
      query(
        collection(db, "activityResults"),
        where("childUserId", "==", uid),
        where("childId", "==", childId),
      ),
    );
    assert.equal(ownResults.size, 2);
    assert.equal(
      ownResults.docs.some((item) => item.id === interruptedSessionId),
      false,
    );

    const activityAfter = await getDoc(doc(db, "activities", activityId));
    assert.equal(activityAfter.data().status, "assigned");

    console.log(
      `Pictogram emulator documents: sessions=${firstSessionId},${secondSessionId},${interruptedSessionId}; results=${firstSessionId},${secondSessionId}`,
    );
  });
});
