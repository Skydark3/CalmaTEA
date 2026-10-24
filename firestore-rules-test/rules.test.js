const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require("firebase/firestore");

const projectId = "demo-calmatea-local";
let testEnv;

const activity = ({
  childId,
  psychologistId,
  status,
  type = "sequence",
  configuration = {},
}) => ({
  therapyId: `therapy-${childId}`,
  childId,
  psychologistId,
  title: "Actividad de prueba",
  description: "",
  type,
  difficulty: 1,
  instructions: "Sigue los pasos",
  configuration,
  status,
  createdAt: new Date("2026-10-08T12:00:00Z"),
  updatedAt: new Date("2026-10-08T12:00:00Z"),
});

const session = ({
  id,
  activityId = "child-a-assigned",
  childId = "child-a",
  psychologistId = "psych-a",
  childUserId = "child-a-auth",
  therapyId = `therapy-${childId}`,
  ...extra
}) => ({
  id,
  activityId,
  therapyId,
  childId,
  psychologistId,
  childUserId,
  status: "inProgress",
  startedAt: serverTimestamp(),
  ...extra,
});

const result = ({
  id,
  activityId = "child-a-assigned",
  childId = "child-a",
  psychologistId = "psych-a",
  childUserId = "child-a-auth",
  therapyId = `therapy-${childId}`,
  activityType = "sequence",
  metrics = { itemsCount: 3, checksCount: 2 },
  ...extra
}) => ({
  id,
  activityId,
  therapyId,
  childId,
  psychologistId,
  childUserId,
  activityType,
  completedAt: serverTimestamp(),
  metrics,
  schemaVersion: 1,
  ...extra,
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await Promise.all([
      setDoc(doc(db, "users", "child-a-auth"), {
        id: "child-a-auth",
        name: "Child A",
        email: "child-a@example.com",
        role: "child",
        childId: "child-a",
        createdAt: new Date(),
      }),
      setDoc(doc(db, "users", "child-b-auth"), {
        id: "child-b-auth",
        name: "Child B",
        email: "child-b@example.com",
        role: "child",
        childId: "child-b",
        createdAt: new Date(),
      }),
      setDoc(doc(db, "users", "child-unlinked-auth"), {
        id: "child-unlinked-auth",
        name: "Unlinked",
        email: "unlinked@example.com",
        role: "child",
        createdAt: new Date(),
      }),
      setDoc(doc(db, "users", "psych-a"), {
        id: "psych-a",
        name: "Psychologist A",
        email: "psych-a@example.com",
        role: "psychologist",
        createdAt: new Date(),
      }),
      setDoc(doc(db, "users", "psych-b"), {
        id: "psych-b",
        name: "Psychologist B",
        email: "psych-b@example.com",
        role: "psychologist",
        createdAt: new Date(),
      }),
      setDoc(doc(db, "children", "child-a"), {
        psychologistId: "psych-a",
        fullName: "Child A",
      }),
      setDoc(doc(db, "children", "child-b"), {
        psychologistId: "psych-b",
        fullName: "Child B",
      }),
      setDoc(doc(db, "therapies", "therapy-child-a"), {
        childId: "child-a",
        psychologistId: "psych-a",
      }),
      setDoc(doc(db, "therapies", "therapy-child-b"), {
        childId: "child-b",
        psychologistId: "psych-b",
      }),
    ]);

    await Promise.all([
      setDoc(
        doc(db, "activities", "child-a-assigned"),
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "assigned",
        }),
      ),
      setDoc(
        doc(db, "activities", "child-a-progress"),
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "inProgress",
        }),
      ),
      setDoc(
        doc(db, "activities", "child-a-completed"),
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "completed",
        }),
      ),
      setDoc(
        doc(db, "activities", "child-a-cancelled"),
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "cancelled",
        }),
      ),
      setDoc(
        doc(db, "activities", "child-b-assigned"),
        activity({
          childId: "child-b",
          psychologistId: "psych-b",
          status: "assigned",
        }),
      ),
    ]);
  });
});

after(async () => {
  await testEnv.cleanup();
});

function childDb(uid = "child-a-auth") {
  return testEnv.authenticatedContext(uid).firestore();
}

function visibleActivitiesQuery(db, childId) {
  return query(
    collection(db, "activities"),
    where("childId", "==", childId),
    where("status", "in", ["assigned", "inProgress"]),
  );
}

async function createSession(db, sessionId, options = {}) {
  const value = session({ id: sessionId, ...options });
  const batch = writeBatch(db);
  batch.set(doc(db, "sessions", sessionId), value);
  batch.set(doc(db, "activeExecutionSessions", value.childId), {
    sessionId,
    activityId: value.activityId,
    childId: value.childId,
    psychologistId: value.psychologistId,
    childUserId: value.childUserId,
    startedAt: serverTimestamp(),
  });
  return batch.commit();
}

async function completeSession(db, sessionId, resultOptions = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, "sessions", sessionId), {
    status: "completed",
    endedAt: serverTimestamp(),
  });
  batch.set(
    doc(db, "activityResults", sessionId),
    result({ id: sessionId, ...resultOptions }),
  );
  batch.delete(doc(db, "activeExecutionSessions", "child-a"));
  return batch.commit();
}

async function interruptSession(db, sessionId, childId = "child-a") {
  const batch = writeBatch(db);
  batch.update(doc(db, "sessions", sessionId), {
    status: "interrupted",
    endedAt: serverTimestamp(),
  });
  batch.delete(doc(db, "activeExecutionSessions", childId));
  return batch.commit();
}

describe("child activities security", () => {
  it("allows a linked child to query assigned and in-progress activities", async () => {
    const db = childDb();
    const snapshot = await assertSucceeds(
      getDocs(visibleActivitiesQuery(db, "child-a")),
    );

    const ids = snapshot.docs.map((item) => item.id).sort();
    if (
      ids.length !== 2 ||
      ids[0] !== "child-a-assigned" ||
      ids[1] !== "child-a-progress"
    ) {
      throw new Error(`Unexpected visible activities: ${ids.join(",")}`);
    }
  });

  it("prevents Child A from reading Child B activities", async () => {
    const db = childDb();
    await assertFails(getDoc(doc(db, "activities", "child-b-assigned")));
    await assertFails(getDocs(visibleActivitiesQuery(db, "child-b")));
  });

  it("denies activity access to a child without a valid link", async () => {
    const db = childDb("child-unlinked-auth");
    await assertFails(getDocs(visibleActivitiesQuery(db, "child-a")));
  });

  it("hides completed and cancelled activities from the child", async () => {
    const db = childDb();
    await assertFails(getDoc(doc(db, "activities", "child-a-completed")));
    await assertFails(getDoc(doc(db, "activities", "child-a-cancelled")));
  });

  it("prevents child changes to activities and profile link", async () => {
    const db = childDb();
    await assertFails(
      updateDoc(doc(db, "activities", "child-a-assigned"), {
        status: "inProgress",
      }),
    );
    await assertFails(
      updateDoc(doc(db, "activities", "child-a-assigned"), {
        configuration: { items: [] },
      }),
    );
    await assertFails(
      updateDoc(doc(db, "users", "child-a-auth"), { childId: "child-b" }),
    );
  });

  it("prevents a child from creating or deleting activities", async () => {
    const db = childDb();
    await assertFails(
      setDoc(
        doc(db, "activities", "child-created"),
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "assigned",
        }),
      ),
    );
    await assertFails(deleteDoc(doc(db, "activities", "child-a-assigned")));
  });

  it("keeps psychologist reads and denies child clinical reads", async () => {
    const psychologistDb = testEnv.authenticatedContext("psych-a").firestore();
    const db = childDb();
    await assertSucceeds(
      getDoc(doc(psychologistDb, "activities", "child-a-assigned")),
    );
    await assertFails(getDoc(doc(db, "children", "child-a")));
    await assertFails(getDoc(doc(db, "therapies", "therapy-child-a")));
  });

  it("keeps psychologist create, update and delete permissions", async () => {
    const db = testEnv.authenticatedContext("psych-a").firestore();
    const createdActivity = doc(db, "activities", "psych-created");
    await assertSucceeds(
      setDoc(
        createdActivity,
        activity({
          childId: "child-a",
          psychologistId: "psych-a",
          status: "assigned",
        }),
      ),
    );
    await assertSucceeds(
      updateDoc(createdActivity, { title: "Actividad actualizada" }),
    );
    await assertSucceeds(deleteDoc(createdActivity));
  });

  it("supports one-step configured assignment and linked-child read for all activity types", async () => {
    const configurations = {
      sequence: {
        version: 1,
        items: [{ id: "step-1", label: "Paso", order: 0 }],
      },
      dragDrop: {
        version: 1,
        items: [
          { id: "item-1", label: "Manzana", targetId: "target-1" },
        ],
        targets: [{ id: "target-1", label: "Frutas" }],
      },
      matching: {
        version: 1,
        pairs: [{ id: "pair-1", left: "Sol", right: "Día" }],
      },
      pictogram: {
        version: 1,
        options: [{ id: "option-1", label: "Agua" }],
      },
      emotion: {
        version: 1,
        options: [
          {
            id: "emotion-1",
            label: "Alegría",
            prompt: "¿Cómo se siente?",
            expectedValue: "alegría",
          },
        ],
      },
      tracing: { version: 1, pattern: "Letra", value: "A" },
      timer: { version: 1, durationSeconds: 30 },
      motor: {
        version: 1,
        steps: [{ id: "motor-1", instruction: "Levanta brazos" }],
      },
    };
    const psychologistDb = testEnv
      .authenticatedContext("psych-a")
      .firestore();

    for (const [type, configuration] of Object.entries(configurations)) {
      const reference = doc(
        psychologistDb,
        "activities",
        `configured-${type}`,
      );
      await assertSucceeds(
        setDoc(
          reference,
          activity({
            childId: "child-a",
            psychologistId: "psych-a",
            status: "assigned",
            type,
            configuration,
          }),
        ),
      );
    }

    const snapshot = await assertSucceeds(
      getDocs(
        query(
          collection(childDb(), "activities"),
          where("childId", "==", "child-a"),
          where("status", "in", ["assigned", "inProgress"]),
        ),
      ),
    );
    const configuredDocuments = snapshot.docs.filter((document) =>
      document.id.startsWith("configured-"),
    );
    assert.equal(configuredDocuments.length, Object.keys(configurations).length);
    for (const document of configuredDocuments) {
      assert.deepEqual(
        document.data().configuration,
        configurations[document.data().type],
      );
    }
  });
});

describe("execution sessions security", () => {
  it("allows a linked child to start a session with server timestamp", async () => {
    await assertSucceeds(createSession(childDb(), "session-valid"));
  });

  it("denies sessions for another child or forged ownership", async () => {
    const db = childDb();
    await assertFails(
      createSession(db, "session-other", {
        activityId: "child-b-assigned",
        childId: "child-b",
        therapyId: "therapy-child-b",
        psychologistId: "psych-b",
      }),
    );
    await assertFails(
      createSession(db, "session-forged-psych", {
        psychologistId: "psych-b",
      }),
    );
    await assertFails(
      createSession(db, "session-forged-therapy", {
        therapyId: "therapy-child-b",
      }),
    );
  });

  it("denies starts for completed or cancelled activities", async () => {
    const db = childDb();
    await assertFails(
      createSession(db, "session-completed", {
        activityId: "child-a-completed",
      }),
    );
    await assertFails(
      createSession(db, "session-cancelled", {
        activityId: "child-a-cancelled",
      }),
    );
  });

  it("denies client timestamps, extra fields and unauthenticated starts", async () => {
    const db = childDb();
    await assertFails(
      createSession(db, "session-client-time", {
        startedAt: new Date("2026-10-10T12:00:00Z"),
      }),
    );
    await assertFails(
      createSession(db, "session-extra", { notes: "dato no permitido" }),
    );
    const anonymousDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(createSession(anonymousDb, "session-anonymous"));
  });

  it("allows interruption without creating a result", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-interrupted"));
    await assertFails(
      updateDoc(doc(db, "sessions", "session-interrupted"), {
        status: "interrupted",
        endedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(interruptSession(db, "session-interrupted"));
    let resultExists = true;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(
        doc(context.firestore(), "activityResults", "session-interrupted"),
      );
      resultExists = snapshot.exists();
    });
    if (resultExists) throw new Error("Unexpected result document");
  });

  it("denies identity changes, direct completion and deletion", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-protected"));
    await assertFails(
      updateDoc(doc(db, "sessions", "session-protected"), {
        childId: "child-b",
        status: "interrupted",
        endedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, "sessions", "session-protected"), {
        status: "completed",
        endedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(db, "sessions", "session-protected")));
  });

  it("denies reopening a terminal session", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-terminal"));
    await assertSucceeds(completeSession(db, "session-terminal"));
    await assertFails(
      updateDoc(doc(db, "sessions", "session-terminal"), {
        status: "inProgress",
      }),
    );
  });
});

describe("activity results security", () => {
  it("atomically completes a session and creates one valid result", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-result"));
    await assertSucceeds(
      completeSession(db, "session-result", { durationSeconds: 45 }),
    );

    const snapshot = await assertSucceeds(
      getDoc(doc(db, "activityResults", "session-result")),
    );
    if (!snapshot.exists() || snapshot.data().schemaVersion !== 1) {
      throw new Error("Expected a schemaVersion 1 result");
    }
  });

  it("keeps closure possible after the professional changes activity status", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-status-change"));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "activities", "child-a-assigned"),
        { status: "completed" },
      );
    });
    await assertSucceeds(completeSession(db, "session-status-change"));
  });

  it("accepts only the aggregate schema defined for each motor", async () => {
    const cases = [
      ["sequence", { itemsCount: 3, checksCount: 2 }],
      ["matching", { relationsCompleted: 2, checksCount: 3 }],
      ["emotion", { exercisesReviewed: 2 }],
      ["pictogram", { interactionsCount: 4 }],
      ["dragDrop", { itemsPlaced: 3, checksCount: 2 }],
      [
        "timer",
        { configuredDurationSeconds: 60, elapsedSeconds: 58 },
      ],
      ["tracing", { practiceCompleted: true, strokesCount: 5 }],
      ["motor", { stepsVisited: 4 }],
    ];

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all(
        cases.map(([type]) =>
          setDoc(
            doc(db, "activities", `child-a-${type}`),
            activity({
              childId: "child-a",
              psychologistId: "psych-a",
              status: "assigned",
              type,
            }),
          ),
        ),
      );
    });

    const db = childDb();
    for (const [type, metrics] of cases) {
      const sessionId = `session-${type}`;
      const activityId = `child-a-${type}`;
      await assertSucceeds(createSession(db, sessionId, { activityId }));
      await assertSucceeds(
        completeSession(db, sessionId, {
          activityId,
          activityType: type,
          metrics,
        }),
      );
    }
  });

  it("denies a result without an in-progress session", async () => {
    const db = childDb();
    await assertFails(
      setDoc(
        doc(db, "activityResults", "missing-session"),
        result({ id: "missing-session" }),
      ),
    );
  });

  it("denies mismatched result id, identity and activity type", async () => {
    const db = childDb();

    await assertSucceeds(createSession(db, "session-mismatch-id"));
    await assertFails(
      completeSession(db, "session-mismatch-id", { id: "different-id" }),
    );
    await assertSucceeds(interruptSession(db, "session-mismatch-id"));

    await assertSucceeds(createSession(db, "session-mismatch-owner"));
    await assertFails(
      completeSession(db, "session-mismatch-owner", {
        psychologistId: "psych-b",
      }),
    );
    await assertSucceeds(interruptSession(db, "session-mismatch-owner"));

    await assertSucceeds(createSession(db, "session-mismatch-type"));
    await assertFails(
      completeSession(db, "session-mismatch-type", {
        activityType: "emotion",
        metrics: { exercisesReviewed: 1 },
      }),
    );
    await assertSucceeds(interruptSession(db, "session-mismatch-type"));
  });

  it("denies invalid, extra or sensitive metrics", async () => {
    const db = childDb();

    await assertSucceeds(createSession(db, "session-zero-metric"));
    await assertFails(
      completeSession(db, "session-zero-metric", {
        metrics: { itemsCount: 0, checksCount: 1 },
      }),
    );
    await assertSucceeds(interruptSession(db, "session-zero-metric"));

    await assertSucceeds(createSession(db, "session-extra-metric"));
    await assertFails(
      completeSession(db, "session-extra-metric", {
        metrics: { itemsCount: 1, checksCount: 1, answer: "sensitive" },
      }),
    );
    await assertSucceeds(interruptSession(db, "session-extra-metric"));

    await assertSucceeds(createSession(db, "session-extra-result-field"));
    await assertFails(
      completeSession(db, "session-extra-result-field", {
        notes: "sensitive",
      }),
    );
    await assertSucceeds(interruptSession(db, "session-extra-result-field"));
  });

  it("makes a result immutable and prevents duplicate completion", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-immutable"));
    await assertSucceeds(completeSession(db, "session-immutable"));
    await assertFails(
      updateDoc(doc(db, "activityResults", "session-immutable"), {
        durationSeconds: 99,
      }),
    );
    await assertFails(
      deleteDoc(doc(db, "activityResults", "session-immutable")),
    );
    await assertFails(completeSession(db, "session-immutable"));
  });

  it("allows only the owning psychologist to read and query records", async () => {
    const db = childDb();
    await assertSucceeds(createSession(db, "session-professional"));
    await assertSucceeds(completeSession(db, "session-professional"));

    const psychA = testEnv.authenticatedContext("psych-a").firestore();
    const psychB = testEnv.authenticatedContext("psych-b").firestore();
    await assertSucceeds(
      getDoc(doc(psychA, "sessions", "session-professional")),
    );
    await assertSucceeds(
      getDoc(doc(psychA, "activityResults", "session-professional")),
    );
    await assertFails(
      getDoc(doc(psychB, "sessions", "session-professional")),
    );
    await assertFails(
      getDoc(doc(psychB, "activityResults", "session-professional")),
    );

    await assertSucceeds(
      getDocs(
        query(
          collection(psychA, "sessions"),
          where("psychologistId", "==", "psych-a"),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(psychA, "activityResults"),
          where("psychologistId", "==", "psych-a"),
        ),
      ),
    );
    await assertFails(getDocs(collection(psychA, "sessions")));
    await assertFails(getDocs(collection(psychA, "activityResults")));
  });
});
