'use strict';

// Local artifact preparation only. No Firebase client, credentials, or network.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const previous = path.join(root, 'tools/phase10-final-audit');
const published = path.join(previous, 'published-2026-10-31');
const oldManifest = JSON.parse(fs.readFileSync(path.join(published, 'manifest.json'), 'utf8'));
const hash = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
for (const [name, digest] of Object.entries(oldManifest.files)) {
  assert.equal(hash(fs.readFileSync(path.join(published, name))), digest, `Published backup changed: ${name}`);
}
function read(name) { return fs.readFileSync(name, 'utf8').replace(/\r\n/g, '\n'); }
function block(source, declaration) {
  const start = source.indexOf(declaration);
  assert.ok(start >= 0, `Missing ${declaration}`);
  const opening = source.indexOf('{', start + declaration.length);
  let depth = 0;
  for (let i = opening; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error('Unclosed rules block');
}
const rules = read(path.join(root, 'firestore.rules'));
const priorRules = read(path.join(previous, 'proposed-2026-10-31/firestore.rules'));
const productionRules = read(path.join(published, 'firestore.rules'));
const declaration = 'match /activities/{activityId}';
const priorActivity = block(priorRules, declaration);
const currentActivity = block(rules, declaration);
const expectedActivity = priorActivity.replace(
  '                    && request.resource.data.createdAt == resource.data.createdAt\n',
  '                    && request.resource.data.createdAt == resource.data.createdAt\n                    && request.resource.data.type == resource.data.type\n',
).replace(
  '      allow delete: if isAuthenticatedPsychologist()\n                    && isActivityOwner();',
  '      // Toda actividad persistida ya está asignada (no hay estado draft).\n      // Retirarla mediante status=cancelled conserva sesiones e historial y\n      // evita una comprobación de sesiones susceptible a carreras.\n      allow delete: if false;',
);
assert.notEqual(expectedActivity, priorActivity);
assert.equal(currentActivity, expectedActivity, 'Unexpected change in activities permissions');
assert.equal(rules.replace(currentActivity, priorActivity), priorRules, 'Rules changed outside activities');
const unchangedCollections = ['users/{uid}', 'psychologists/{uid}', 'children/{childId}', 'therapies/{therapyId}'];
for (const collection of unchangedCollections) {
  assert.equal(block(rules, `match /${collection}`), block(productionRules, `match /${collection}`));
}
assert.equal(block(productionRules, declaration), priorActivity, 'Published activities differ from prior audit');
assert.equal(read(path.join(root, 'firestore.indexes.json')), read(path.join(previous, 'proposed-2026-10-31/firestore.indexes.json')));

const candidate = path.join(__dirname, 'candidate');
fs.mkdirSync(candidate, { recursive: true });
const files = {};
for (const name of ['firestore.rules', 'firestore.indexes.json']) {
  const bytes = fs.readFileSync(path.join(root, name));
  const target = path.join(candidate, name);
  if (fs.existsSync(target)) assert.deepEqual(fs.readFileSync(target), bytes, 'Candidate changed: review required');
  else fs.writeFileSync(target, bytes, { flag: 'wx' });
  files[name] = hash(bytes);
}
const report = {
  productionProject: 'calmatea-4c781',
  testProject: 'demo-calmatea-local',
  existingProductionCollectionsUnchanged: unchangedCollections,
  intentionalRestrictions: ['activities.type immutable on every update', 'activities physical delete denied for all client identities'],
  phase10RulesOutsideActivitiesUnchanged: true,
  schemaChanges: false,
  migrations: false,
  additionalIndexes: false,
  newQueries: false,
  candidateSha256: files,
  productionWrites: 0,
};
fs.writeFileSync(path.join(__dirname, 'comparison.json'), `${JSON.stringify(report, null, 2)}\n`);
const config = { firestore: { rules: path.join(candidate, 'firestore.rules').replace(/\\/g, '/') } };
fs.writeFileSync(path.join(__dirname, 'deploy.rules.json'), `${JSON.stringify(config, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
