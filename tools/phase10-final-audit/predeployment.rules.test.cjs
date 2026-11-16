'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('../../firestore-rules-test/node_modules/@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } = require('../../firestore-rules-test/node_modules/firebase/firestore');
const projectId = 'demo-calmatea-local';
let env;

async function start(db, id) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'sessions', id), {
    id, activityId: 'activity-a', therapyId: 'therapy-a', childId: 'child-a',
    psychologistId: 'psych-a', childUserId: 'child-auth-a',
    status: 'inProgress', startedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'activeExecutionSessions', 'child-a'), {
    sessionId: id, activityId: 'activity-a', childId: 'child-a',
    psychologistId: 'psych-a', childUserId: 'child-auth-a', startedAt: serverTimestamp(),
  });
  return batch.commit();
}
async function interrupt(db, id, lockChildId = 'child-a') {
  const batch = writeBatch(db);
  batch.update(doc(db, 'sessions', id), { status: 'interrupted', endedAt: serverTimestamp() });
  batch.delete(doc(db, 'activeExecutionSessions', lockChildId));
  return batch.commit();
}

describe('final predeployment audit (local only)', () => {
  before(async () => {
    assert.equal(process.env.GCLOUD_PROJECT, projectId);
    assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
    env = await initializeTestEnvironment({ projectId, firestore: { rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') } });
  });
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = new Date('2026-10-01T12:00:00Z');
      await Promise.all([
        setDoc(doc(db, 'users', 'child-auth-a'), { id: 'child-auth-a', role: 'child', childId: 'child-a' }),
        setDoc(doc(db, 'users', 'child-auth-b'), { id: 'child-auth-b', role: 'child', childId: 'child-b' }),
        setDoc(doc(db, 'users', 'psych-a'), { id: 'psych-a', role: 'psychologist' }),
        setDoc(doc(db, 'children', 'child-a'), { psychologistId: 'psych-a' }),
        setDoc(doc(db, 'therapies', 'therapy-a'), { childId: 'child-a', psychologistId: 'psych-a' }),
        setDoc(doc(db, 'activities', 'activity-a'), {
          therapyId: 'therapy-a', childId: 'child-a', psychologistId: 'psych-a',
          title: 'Fixture local', description: '', type: 'sequence', difficulty: 1,
          instructions: 'Ordena', configuration: { version: 1, items: [{ id: 'a', label: 'Paso', order: 0 }] },
          status: 'assigned', createdAt: now, updatedAt: now,
        }),
      ]);
    });
  });
  after(async () => { await env?.cleanup(); });

  it('cannot replace the first lock or release it from another child', async () => {
    const db = env.authenticatedContext('child-auth-a').firestore();
    await assertSucceeds(start(db, 'first'));
    await assertFails(start(db, 'replacement'));
    await assertFails(deleteDoc(doc(env.authenticatedContext('child-auth-b').firestore(), 'activeExecutionSessions', 'child-a')));
    assert.equal((await getDoc(doc(db, 'activeExecutionSessions', 'child-a'))).data().sessionId, 'first');
  });

  it('rejects interruption that deletes the wrong child lock', async () => {
    const db = env.authenticatedContext('child-auth-a').firestore();
    await start(db, 'current');
    await assertFails(interrupt(db, 'current', 'child-b'));
    assert.equal((await getDoc(doc(db, 'sessions', 'current'))).data().status, 'inProgress');
    assert.equal((await getDoc(doc(db, 'activeExecutionSessions', 'child-a'))).data().sessionId, 'current');
  });

  it('a delayed close of an old session cannot delete the new lock', async () => {
    const db = env.authenticatedContext('child-auth-a').firestore();
    await start(db, 'old');
    await interrupt(db, 'old');
    await start(db, 'new');
    await assertFails(interrupt(db, 'old'));
    assert.equal((await getDoc(doc(db, 'activeExecutionSessions', 'child-a'))).data().sessionId, 'new');
  });

  it('fails closed for an inconsistent lock rather than deleting it', async () => {
    const db = env.authenticatedContext('child-auth-a').firestore();
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'activeExecutionSessions', 'child-a'), {
        sessionId: 'missing', activityId: 'activity-a', childId: 'child-a',
        psychologistId: 'psych-a', childUserId: 'child-auth-a', startedAt: new Date(),
      });
    });
    await assertFails(deleteDoc(doc(db, 'activeExecutionSessions', 'child-a')));
    await assertFails(start(db, 'replacement'));
  });

  it('keeps terminal activity reads restricted while allowing interruption', async () => {
    const db = env.authenticatedContext('child-auth-a').firestore();
    await start(db, 'status-changed');
    await assertSucceeds(updateDoc(doc(env.authenticatedContext('psych-a').firestore(), 'activities', 'activity-a'), { status: 'completed' }));
    // The fixed Dart completeSession no longer performs this GET.
    // Existing activity read permissions deliberately disallow terminal status.
    await assertFails(getDoc(doc(db, 'activities', 'activity-a')));
    // Recovery can safely interrupt instead, without needing activity read.
    await assertSucceeds(interrupt(db, 'status-changed'));
    assert.equal((await getDoc(doc(db, 'activeExecutionSessions', 'child-a'))).exists(), false);
  });
});
