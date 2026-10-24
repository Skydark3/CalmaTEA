const {
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");

const projectId = "demo-calmatea-local";
const psychologistEmail = "psychologist@calmatea.test";
const childEmail = "child@calmatea.test";
const localPassword = "CalmaTEA-Local-Only-2026!";

function requireLocalEmulator(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required. Run this script with emulators:exec.`);
  }
  if (!/^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(value)) {
    throw new Error(`${name} must point to a loopback address.`);
  }
  return value;
}

async function resetAuthEmulator(authHost) {
  const response = await fetch(
    `http://${authHost}/emulator/v1/projects/${projectId}/accounts`,
    { method: "DELETE" },
  );
  if (!response.ok) {
    throw new Error(`Unable to reset Auth Emulator (${response.status}).`);
  }
}

async function createAuthUser(authHost, email) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-emulator-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email,
        password: localPassword,
        returnSecureToken: true,
      }),
    },
  );
  const payload = await response.json();
  if (!response.ok || typeof payload.localId !== "string") {
    throw new Error(`Unable to create local Auth user ${email}.`);
  }
  return payload.localId;
}

function activity({
  id,
  type,
  title,
  configuration,
  psychologistId,
  childId,
  therapyId,
  status = "assigned",
  createdAt,
}) {
  return {
    id,
    data: {
      therapyId,
      childId,
      psychologistId,
      title,
      description: "Actividad local de validacion funcional.",
      type,
      difficulty: 1,
      instructions: "Sigue las instrucciones en pantalla.",
      configuration,
      status,
      createdAt,
      updatedAt: createdAt,
    },
  };
}

async function main() {
  const authHost = requireLocalEmulator("FIREBASE_AUTH_EMULATOR_HOST");
  requireLocalEmulator("FIRESTORE_EMULATOR_HOST");
  if (process.env.GCLOUD_PROJECT !== projectId) {
    throw new Error(`GCLOUD_PROJECT must be exactly ${projectId}.`);
  }

  await resetAuthEmulator(authHost);
  const psychologistId = await createAuthUser(authHost, psychologistEmail);
  const childAuthId = await createAuthUser(authHost, childEmail);

  const testEnv = await initializeTestEnvironment({ projectId });
  try {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const childId = "child-local-a";
      const otherChildId = "child-local-b";
      const therapyId = "therapy-local-a";
      const otherTherapyId = "therapy-local-b";
      const now = new Date("2026-10-08T15:00:00Z");

      await Promise.all([
        setDoc(doc(db, "users", psychologistId), {
          id: psychologistId,
          name: "Psicologa Local",
          email: psychologistEmail,
          role: "psychologist",
          createdAt: now,
        }),
        setDoc(doc(db, "psychologists", psychologistId), {
          id: psychologistId,
          userId: psychologistId,
          fullName: "Psicologa Local",
          email: psychologistEmail,
          specialty: "Validacion local",
          professionalLicense: "LOCAL-TEST",
          workCenter: "Firebase Emulator Suite",
          photoUrl: null,
          createdAt: now,
          updatedAt: now,
        }),
        setDoc(doc(db, "users", childAuthId), {
          id: childAuthId,
          name: "Alex Prueba",
          email: childEmail,
          role: "child",
          childId,
          createdAt: now,
        }),
        setDoc(doc(db, "children", childId), {
          psychologistId,
          fullName: "Alex Prueba",
          birthDate: new Date("2014-05-12T12:00:00Z"),
          supportLevel: "Nivel 1 - Requiere apoyo",
          notes: null,
          photoUrl: null,
          createdAt: now,
          updatedAt: now,
        }),
        setDoc(doc(db, "children", otherChildId), {
          psychologistId,
          fullName: "Paciente Local B",
          birthDate: new Date("2013-03-10T12:00:00Z"),
          supportLevel: "Nivel 1 - Requiere apoyo",
          notes: null,
          photoUrl: null,
          createdAt: now,
          updatedAt: now,
        }),
        setDoc(doc(db, "therapies", therapyId), {
          childId,
          psychologistId,
          type: "occupational",
          status: "active",
          startDate: new Date("2026-10-01T12:00:00Z"),
          notes: null,
          createdAt: now,
          updatedAt: now,
        }),
        setDoc(doc(db, "therapies", otherTherapyId), {
          childId: otherChildId,
          psychologistId,
          type: "language",
          status: "active",
          startDate: new Date("2026-10-01T12:00:00Z"),
          notes: null,
          createdAt: now,
          updatedAt: now,
        }),
      ]);

      const configurations = [
        activity({
          id: "activity-sequence",
          type: "sequence",
          title: "Secuencia local",
          configuration: {
            version: 1,
            items: [
              { id: "seq-1", label: "Abrir mochila", order: 0 },
              { id: "seq-2", label: "Guardar cuaderno", order: 1 },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:01:00Z"),
        }),
        activity({
          id: "activity-matching",
          type: "matching",
          title: "Matching local",
          configuration: {
            version: 1,
            pairs: [
              { id: "match-1", left: "Gato", right: "Animal" },
              { id: "match-2", left: "Azul", right: "Color" },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:02:00Z"),
        }),
        activity({
          id: "activity-emotion",
          type: "emotion",
          title: "Emociones local",
          configuration: {
            version: 1,
            options: [
              {
                id: "emotion-1",
                label: "Alegria",
                prompt: "Como te sentirias al recibir un regalo?",
                expectedValue: "alegria",
              },
              {
                id: "emotion-2",
                label: "Calma",
                prompt: "Como se siente una respiracion tranquila?",
                expectedValue: "calma",
              },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:03:00Z"),
        }),
        activity({
          id: "activity-pictogram",
          type: "pictogram",
          title: "Pictogramas local",
          configuration: {
            version: 1,
            options: [
              { id: "pictogram-water", label: "Agua" },
              { id: "pictogram-rest", label: "Descansar" },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:04:00Z"),
        }),
        activity({
          id: "activity-drag-drop",
          type: "dragDrop",
          title: "Drag Drop local",
          configuration: {
            version: 1,
            items: [
              { id: "apple", label: "Manzana", targetId: "fruits" },
              { id: "carrot", label: "Zanahoria", targetId: "vegetables" },
            ],
            targets: [
              { id: "fruits", label: "Frutas" },
              { id: "vegetables", label: "Verduras" },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:05:00Z"),
        }),
        activity({
          id: "activity-timer",
          type: "timer",
          title: "Timer local",
          configuration: {
            version: 1,
            durationSeconds: 5,
            label: "Respiracion breve",
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:06:00Z"),
        }),
        activity({
          id: "activity-tracing",
          type: "tracing",
          title: "Tracing local",
          configuration: {
            version: 1,
            pattern: "letter",
            value: "A",
            difficultyHint: "Inicial",
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:07:00Z"),
        }),
        activity({
          id: "activity-motor",
          type: "motor",
          title: "Motor local",
          configuration: {
            version: 1,
            steps: [
              { id: "motor-1", instruction: "Levanta ambos brazos" },
              { id: "motor-2", instruction: "Baja ambos brazos" },
            ],
          },
          psychologistId,
          childId,
          therapyId,
          createdAt: new Date("2026-10-08T15:08:00Z"),
        }),
        activity({
          id: "activity-completed",
          type: "sequence",
          title: "Actividad completada oculta",
          configuration: {
            version: 1,
            items: [{ id: "done-1", label: "Finalizada", order: 0 }],
          },
          psychologistId,
          childId,
          therapyId,
          status: "completed",
          createdAt: new Date("2026-10-08T15:09:00Z"),
        }),
        activity({
          id: "activity-cancelled",
          type: "sequence",
          title: "Actividad cancelada oculta",
          configuration: {
            version: 1,
            items: [{ id: "cancelled-1", label: "Cancelada", order: 0 }],
          },
          psychologistId,
          childId,
          therapyId,
          status: "cancelled",
          createdAt: new Date("2026-10-08T15:10:00Z"),
        }),
        activity({
          id: "activity-other-child",
          type: "sequence",
          title: "Actividad privada de otro paciente",
          configuration: {
            version: 1,
            items: [{ id: "other-1", label: "Privada", order: 0 }],
          },
          psychologistId,
          childId: otherChildId,
          therapyId: otherTherapyId,
          createdAt: new Date("2026-10-08T15:11:00Z"),
        }),
      ];

      await Promise.all(
        configurations.map(({ id, data }) =>
          setDoc(doc(db, "activities", id), data),
        ),
      );
    });
  } finally {
    await testEnv.cleanup();
  }

  console.log("Local CalmaTEA fixtures created successfully.");
  console.log(`Psychologist: ${psychologistEmail}`);
  console.log(`Child: ${childEmail}`);
  console.log("Password is the documented local-only fixture password.");
}

main().catch((error) => {
  console.error(`Seed failed: ${error.message}`);
  process.exitCode = 1;
});
