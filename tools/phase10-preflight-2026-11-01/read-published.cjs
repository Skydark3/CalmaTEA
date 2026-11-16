'use strict';

// Metadata GETs only. Never deploys, queries application documents or prints ADC.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { GoogleAuth } = require('../../functions/node_modules/google-auth-library');

const projectId = 'calmatea-4c781';
const databaseId = '(default)';
const mode = process.argv[2] || '--preflight';
assert.ok(['--preflight', '--ready', '--candidate', '--rollback'].includes(mode), 'INVALID_MODE');
const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}`;
const projectUrl = `https://firebase.googleapis.com/v1beta1/projects/${projectId}`;
const rulesRoot = `https://firebaserules.googleapis.com/v1/projects/${projectId}`;
const releaseUrl = `${rulesRoot}/releases/cloud.firestore`;
const load = (p) => JSON.parse(fs.readFileSync(path.join(__dirname, p), 'utf8'));
const hash = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const backup = load('backup/manifest.json');
const frozenHashes = {
  backup: 'd3d6661464da65f0101bbc1304e1c452527f57d59216be8ec4e52d8cfe77029e',
  candidate: '5eb5bc27e86afb3d5509bd6d5ace1beacb1de0f8bf4106c3b558434a0afb089f',
};
const desired = load('candidate/firestore.indexes.json').indexes;
let lastEndpoint;

function normalizedIndex(index) {
  return {
    collectionGroup: index.name.split('/collectionGroups/')[1].split('/')[0],
    queryScope: index.queryScope,
    fields: index.fields.filter((f) => f.fieldPath !== '__name__'),
  };
}

async function main() {
  // ADC is used normally, never obtained from Firebase CLI's private store.
  const client = await new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  }).getClient();
  async function get(url) {
    const parsed = new URL(url);
    const endpoint = `${parsed.origin}${parsed.pathname}`;
    const fixed = [projectUrl, root, releaseUrl,
      `${root}/collectionGroups/-/indexes`, `${root}/collectionGroups/-/fields`];
    const isRuleset = endpoint.startsWith(`${rulesRoot}/rulesets/`)
      && /^[a-zA-Z0-9-]+$/.test(endpoint.slice(`${rulesRoot}/rulesets/`.length));
    assert.ok(fixed.includes(endpoint) || isRuleset, 'UNEXPECTED_METADATA_ENDPOINT');
    for (const key of parsed.searchParams.keys()) {
      assert.ok(['pageToken', 'filter'].includes(key), 'UNEXPECTED_QUERY_PARAMETER');
    }
    lastEndpoint = endpoint;
    return (await client.request({ url, method: 'GET' })).data;
  }
  async function list(url, key) {
    const items = [];
    let token;
    do {
      const next = new URL(url);
      if (token) next.searchParams.set('pageToken', token);
      const page = await get(next.href);
      items.push(...(page[key] || []));
      token = page.nextPageToken;
    } while (token);
    return { [key]: items };
  }

  const project = await get(projectUrl);
  assert.equal(project.projectId, projectId, 'PROJECT_MISMATCH');
  const database = await get(root);
  assert.equal(database.name, `projects/${projectId}/databases/${databaseId}`, 'DATABASE_MISMATCH');
  assert.equal(database.type, 'FIRESTORE_NATIVE', 'DATABASE_TYPE_MISMATCH');
  const release = await get(releaseUrl);
  assert.ok(release.rulesetName.startsWith(`projects/${projectId}/rulesets/`), 'RULESET_PROJECT_MISMATCH');
  const ruleset = await get(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`);
  const files = ruleset.source?.files;
  assert.equal(files?.length, 1, 'UNEXPECTED_RULE_FILES');
  assert.equal(typeof files[0].content, 'string', 'MISSING_RULE_CONTENT');
  const rulesSha256 = hash(Buffer.from(files[0].content, 'utf8'));
  const indexes = await list(`${root}/collectionGroups/-/indexes`, 'indexes');
  const fields = await list(`${root}/collectionGroups/-/fields?filter=indexConfig.usesAncestorConfig%3Dfalse`, 'fields');
  const finalRelease = await get(releaseUrl);
  assert.deepEqual(finalRelease, release, 'RELEASE_CHANGED_DURING_READ');
  assert.deepEqual(fields, load('backup/fields.published.json'), 'FIELD_INDEX_POLICY_CHANGED');

  if (mode === '--preflight' || mode === '--ready') {
    assert.deepEqual(release, load('backup/release.json'), 'PUBLISHED_RELEASE_CHANGED_RENEW_REVIEW');
    assert.deepEqual(ruleset.source, load('backup/ruleset.json').source, 'PUBLISHED_SOURCE_CHANGED');
  }
  if (mode === '--preflight') {
    assert.equal(rulesSha256, frozenHashes.backup, 'BACKUP_SOURCE_MISMATCH');
    assert.deepEqual(indexes, load('backup/indexes.published.json'), 'PUBLISHED_INDEXES_CHANGED');
  } else if (mode === '--ready' || mode === '--candidate') {
    assert.deepEqual(indexes.indexes.map(normalizedIndex), desired, 'INDEX_SET_NOT_EXACTLY_APPROVED');
    assert.ok(indexes.indexes.every((i) => i.state === 'READY'), 'INDEX_NOT_READY');
    assert.equal(rulesSha256, mode === '--candidate' ? frozenHashes.candidate : frozenHashes.backup, 'PUBLISHED_SOURCE_HASH_MISMATCH');
  } else {
    assert.equal(rulesSha256, frozenHashes.backup, 'ROLLBACK_SOURCE_MISMATCH');
    // The additive approved index may remain after a rules-only rollback.
    assert.ok(indexes.indexes.length === 0 || indexes.indexes.length === desired.length, 'UNEXPECTED_INDEX_SET');
    if (indexes.indexes.length) {
      assert.deepEqual(indexes.indexes.map(normalizedIndex), desired, 'UNEXPECTED_INDEX_SET');
    }
  }
  assert.equal(backup.projectId, projectId, 'BACKUP_PROJECT_MISMATCH');
  console.log(JSON.stringify({
    checkedAtUtc: new Date().toISOString(), mode, projectId, databaseId,
    databaseLocation: database.locationId, releaseName: release.name,
    rulesetName: release.rulesetName, releaseUpdateTime: release.updateTime,
    rulesSha256, indexes: indexes.indexes.map((i) => ({ ...normalizedIndex(i), state: i.state })),
    fieldPolicyMatchesBackup: true, releaseStableDuringRead: true,
    applicationDocumentsRead: 0, firebaseWrites: 0, metadataMethods: ['GET'],
  }, null, 2));
}

main().catch((error) => {
  // Do not serialize errors, requests, headers, auth objects or API response bodies.
  console.error(JSON.stringify({
    audit: 'failed', mode, endpoint: lastEndpoint,
    httpStatus: error.response?.status || null,
    code: error.code || error.response?.data?.error?.status || 'PREFLIGHT_FAILED',
    check: error.code === 'ERR_ASSERTION' ? error.message.split('\n')[0] : undefined,
    firebaseWrites: 0,
  }));
  process.exitCode = 1;
});
