'use strict';

// Offline assertions only. No Firebase SDK, network, deployment or file writes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const cliRoot = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools');
const read = (p) => {
  const bytes = fs.readFileSync(p);
  // Windows PowerShell Tee-Object evidence logs use UTF-16LE with BOM.
  return bytes[0] === 0xff && bytes[1] === 0xfe
    ? bytes.subarray(2).toString('utf16le') : bytes.toString('utf8').replace(/^\uFEFF/, '');
};
const json = (p) => JSON.parse(read(p));
const sha = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const fileHash = (p) => sha(fs.readFileSync(p));
const expected = {
  backup: 'd3d6661464da65f0101bbc1304e1c452527f57d59216be8ec4e52d8cfe77029e',
  rules: '5eb5bc27e86afb3d5509bd6d5ace1beacb1de0f8bf4106c3b558434a0afb089f',
  indexes: '0851e25b02ee6d4084a3f0b2836e298bb96b3d3cd0ac8a877ab135b2a02480d7',
};

function block(source, declaration) {
  const start = source.indexOf(declaration);
  assert.ok(start >= 0, `MISSING ${declaration}`);
  const opening = source.indexOf('{', start + declaration.length);
  let depth = 0;
  for (let i = opening; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw Error('UNCLOSED_BLOCK');
}
const canonical = (s) => s.replace(/\/\/[^\n]*/g, '').replace(/\s+/g, ' ').trim();

function treeFingerprint(directory) {
  const files = ['package.json'];
  function walk(p) {
    for (const entry of fs.readdirSync(path.join(directory, p), { withFileTypes: true })) {
      const relative = `${p}/${entry.name}`;
      if (entry.isDirectory()) walk(relative);
      else if (entry.isFile()) files.push(relative);
      else throw Error('UNEXPECTED_CLI_SYMLINK');
    }
  }
  walk('lib');
  files.sort();
  return { fileCount: files.length, algorithm: 'sha256(sorted(relativePath + NUL + fileSha256 + LF))',
    sha256: sha(files.map((p) => `${p}\0${fileHash(path.join(directory, p))}\n`).join('')) };
}

function diff(oldText, newText) {
  const a = oldText.replace(/\r\n/g, '\n').split('\n');
  const b = newText.replace(/\r\n/g, '\n').split('\n');
  const matrix = Array.from({ length: a.length + 1 }, () => new Uint16Array(b.length + 1));
  for (let i = a.length - 1; i >= 0; i--) for (let j = b.length - 1; j >= 0; j--) {
    matrix[i][j] = a[i] === b[j] ? matrix[i + 1][j + 1] + 1 : Math.max(matrix[i + 1][j], matrix[i][j + 1]);
  }
  const lines = ['--- backup/firestore.rules', '+++ candidate/firestore.rules', `@@ -1,${a.length} +1,${b.length} @@`];
  let i = 0, j = 0;
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] === b[j]) { lines.push(` ${a[i++]}`); j++; }
    else if (j < b.length && (i === a.length || matrix[i][j + 1] >= matrix[i + 1][j])) lines.push(`+${b[j++]}`);
    else lines.push(`-${a[i++]}`);
  }
  return `${lines.join('\n')}\n`;
}

function audit(includeDiff = false) {
  const files = {};
  function track(p, wanted) {
    const absolute = path.resolve(__dirname, p);
    const hash = fileHash(absolute);
    if (wanted) assert.equal(hash, wanted, `HASH_CHANGED ${p}`);
    files[path.relative(root, absolute).replace(/\\/g, '/')] = hash;
    return absolute;
  }
  const previousManifest = json(path.join(__dirname, 'backup/manifest.json'));
  assert.equal(previousManifest.projectId, 'calmatea-4c781');
  for (const [name, hash] of Object.entries(previousManifest.files)) {
    track(`backup/${name}`, hash);
    assert.equal(fileHash(path.join(root, 'tools/phase10-final-audit/published-2026-10-31', name)), hash);
  }
  track('backup/manifest.json');
  const oldRules = read(track('backup/firestore.rules', expected.backup));
  const newRules = read(track('candidate/firestore.rules', expected.rules));
  track('candidate/firestore.indexes.json', expected.indexes);
  track('../../firestore.rules', expected.rules);
  track('../../firestore.indexes.json', expected.indexes);
  track('../phase10-activity-integrity/candidate/firestore.rules', expected.rules);
  assert.notEqual(fileHash(path.join(root, 'tools/phase10-final-audit/proposed-2026-10-31/firestore.rules')), expected.rules);

  const unchanged = ['users/{uid}', 'psychologists/{uid}', 'children/{childId}', 'therapies/{therapyId}'];
  for (const collection of unchanged) {
    assert.equal(block(newRules, `match /${collection}`), block(oldRules, `match /${collection}`));
  }
  const newActivities = block(newRules, 'match /activities/{activityId}');
  assert.ok(newActivities.includes('&& request.resource.data.type == resource.data.type'));
  assert.ok(newActivities.includes('allow delete: if false;'));
  const projectedActivities = newActivities
    .replace('&& request.resource.data.type == resource.data.type', '')
    .replace('allow delete: if false;', 'allow delete: if isAuthenticatedPsychologist() && isActivityOwner();');
  assert.equal(canonical(projectedActivities), canonical(block(oldRules, 'match /activities/{activityId}')));
  assert.ok(newActivities.includes("'cancelled'"));
  let oldOutside = oldRules, newOutside = newRules;
  for (const declaration of [...unchanged.map((c) => `match /${c}`), 'match /activities/{activityId}',
    'match /sessions/', 'match /activityResults/']) {
    // Session declarations differ intentionally between published recursive deny and candidate.
    const oldDeclaration = declaration.endsWith('/')
      ? `${declaration}{document=**}` : declaration;
    const newDeclaration = declaration.endsWith('/')
      ? `${declaration}{sessionId}` : declaration;
    oldOutside = oldOutside.replace(block(oldRules, oldDeclaration), '');
    newOutside = newOutside.replace(block(newRules, newDeclaration), '');
  }
  newOutside = newOutside.replace(block(newRules, 'match /activeExecutionSessions/{childId}'), '');
  for (const helper of ['isAuthenticatedPsychologistUser()', 'isAuthenticatedLinkedChildUser(childId)',
    'linkedChildProfileMatches(childId)', 'isNonEmptyId(value)']) {
    newOutside = newOutside.replace(block(newRules, `function ${helper}`), '');
  }
  assert.equal(canonical(newOutside), canonical(oldOutside), 'UNEXPECTED_OTHER_RULES_CHANGE');

  const indexes = json(path.join(__dirname, 'candidate/firestore.indexes.json'));
  assert.deepEqual(indexes, { indexes: [{ collectionGroup: 'sessions', queryScope: 'COLLECTION', fields: [
    { fieldPath: 'psychologistId', order: 'ASCENDING' }, { fieldPath: 'childId', order: 'ASCENDING' },
    { fieldPath: 'startedAt', order: 'DESCENDING' },
  ] }], fieldOverrides: [] });
  const cliFsConfig = require(path.join(cliRoot, 'lib/firestore/fsConfig.js'));
  const configs = {};
  for (const [name, key, file] of [
    ['firebase.rules.json', 'rules', 'candidate/firestore.rules'],
    ['firebase.indexes.json', 'indexes', 'candidate/firestore.indexes.json'],
    ['firebase.rollback.json', 'rules', 'backup/firestore.rules'],
  ]) {
    const configPath = track(name);
    const config = json(configPath);
    assert.deepEqual(config, { firestore: { database: '(default)', [key]: file } });
    // Use the installed CLI's pure configuration resolver; never call deploy/prepare.
    const effective = cliFsConfig.getFirestoreConfig('calmatea-4c781', {
      only: `firestore:${key}`, config: { src: config }, rc: {},
    });
    assert.equal(effective.length, 1);
    assert.equal(effective[0].database, '(default)');
    assert.equal(effective[0][key], file);
    configs[name] = { database: effective[0].database, only: `firestore:${key}`,
      absoluteFile: path.resolve(path.dirname(configPath), file), hooks: [] };
  }
  const appFlagsPath = track('../../lib/core/config/phase10_feature_flags.dart');
  const flagsSource = read(appFlagsPath);
  const featureFlags = ['ENABLE_ACTIVITY_EXECUTION', 'ENABLE_ACTIVITY_PREVIEW',
    'ENABLE_EXECUTION_HISTORY', 'ENABLE_EXECUTION_METRICS'];
  for (const flag of featureFlags) {
    assert.match(flagsSource, new RegExp(`String.fromEnvironment\\(\\s*'${flag}',\\s*defaultValue: 'false'`));
    assert.match(flagsSource, new RegExp(`bool.fromEnvironment\\(\\s*'${flag}',\\s*defaultValue: false`));
  }
  assert.ok(flagsSource.includes('!kReleaseMode') && !flagsSource.includes('FirebaseBootstrap'));
  for (const p of ['../../firebase.json', '../../.firebaserc', '../../lib/main.dart',
    '../../lib/features/auth/presentation/auth_gate.dart', '../../lib/features/child/child_shell.dart',
    '../../lib/services/patient_activity_history_service.dart', '../../lib/services/activity_execution_session_service.dart',
    '../../lib/services/psychologist_execution_metrics_service.dart', 'read-published.cjs', 'verify-local.cjs',
    'read-published.test.cjs', 'published-readonly.json', 'rules.published-to-final.diff', 'REPORT.md']) track(p);
  const evidence = {};
  for (const [name, pattern] of [
    ['flutter-analyze.log', /No issues found!/], ['flutter-test-final.log', /\+480: All tests passed!/],
    ['rules-test.log', /32 passing/], ['phase10-e2e-final.log', /PHASE 10 E2E PASSED \(12\)/],
    ['android-integral-transaction-fix.log', /\+2: All tests passed!/],
    ['android-integral-confirmation.log', /\+2: All tests passed!/],
  ]) {
    const p = track(`../phase10-android-final-evidence/${name}`);
    assert.match(read(p), pattern, `MISSING_FINAL_TEST_RESULT ${name}`);
    evidence[name] = { sha256: fileHash(p), lastModifiedUtc: fs.statSync(p).mtime.toISOString(), reviewedNotRerun: true };
  }
  const cli = { version: json(path.join(cliRoot, 'package.json')).version, nodeVersion: process.version,
    shim: path.resolve(cliRoot, '../../firebase.cmd'), entrypoint: path.join(cliRoot, 'lib/bin/firebase.js'),
    nodeExecutable: process.execPath, libAndPackageTree: treeFingerprint(cliRoot) };
  cli.shimSha256 = fileHash(cli.shim);
  cli.entrypointSha256 = fileHash(cli.entrypoint);
  cli.packageJsonSha256 = fileHash(path.join(cliRoot, 'package.json'));
  cli.nodeExecutableSha256 = fileHash(process.execPath);
  if (fs.existsSync(path.join(__dirname, 'manifest.json'))) {
    const frozen = json(path.join(__dirname, 'manifest.json'));
    assert.deepEqual(files, frozen.files, 'FROZEN_FILES_CHANGED_RENEW_REVIEW');
    assert.deepEqual(cli, frozen.cli, 'CLI_CHANGED_RENEW_REVIEW');
  }
  return { projectId: 'calmatea-4c781', databaseId: '(default)', expectedSha256: expected,
    verifiedBackupFiles: Object.keys(previousManifest.files).length, unchangedLegacyCollections: unchanged,
    activityChanges: ['type immutable', 'physical delete denied; cancelled retained'],
    otherPermissionChanges: ['sessions', 'activityResults', 'activeExecutionSessions'],
    unexpectedPermissionChanges: false, configs, indexes, featureDefaults: Object.fromEntries(featureFlags.map((f) => [f, false])),
    evidence, cli, files, ...(includeDiff ? { diff: diff(oldRules, newRules) } : {}),
    firebaseWrites: 0, networkCalls: 0 };
}

module.exports = { audit };
if (require.main === module) {
  try { console.log(JSON.stringify(audit(), null, 2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
