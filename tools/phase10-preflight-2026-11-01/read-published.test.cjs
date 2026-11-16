'use strict';
// Offline tests of verification commands. Fake metadata only; no ADC/network.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const fakeMetadataProcess = String.raw`
const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const assert = require('node:assert/strict');
const directory = process.argv[1];
const mode = process.argv[2];
const scenario = process.argv[3];
const read = p => JSON.parse(fs.readFileSync(path.join(directory, p), 'utf8'));
const project = 'calmatea-4c781';
const base = 'https://firestore.googleapis.com/v1/projects/' + project + '/databases/(default)';
const release = read('backup/release.json');
const oldSource = read('backup/ruleset.json').source;
const index = {
  name: 'projects/' + project + '/databases/(default)/collectionGroups/sessions/indexes/fake',
  ...read('candidate/firestore.indexes.json').indexes[0],
  state: scenario === 'creating' ? 'CREATING' : 'READY',
};
delete index.collectionGroup;
index.fields.push({ fieldPath: '__name__', order: 'DESCENDING' });
if (mode === '--candidate' || mode === '--rollback') {
  release.rulesetName = 'projects/' + project + '/rulesets/test-publication';
}
let releaseReads = 0;
const originalLoad = Module._load;
Module._load = function (name, parent, isMain) {
  if (name.endsWith('google-auth-library')) return { GoogleAuth: class {
    async getClient() { return { request: async ({url, method}) => {
      assert.equal(method, 'GET');
      assert.ok(!url.includes('/documents'));
      const endpoint = new URL(url).pathname;
      let data;
      if (url === 'https://firebase.googleapis.com/v1beta1/projects/' + project) {
        data = {projectId: scenario === 'wrong-project' ? 'unexpected' : project};
      } else if (url === base) {
        data = {name: 'projects/' + project + '/databases/(default)', type: 'FIRESTORE_NATIVE', locationId: 'southamerica-west1'};
      } else if (endpoint.endsWith('/releases/cloud.firestore')) {
        releaseReads++;
        data = {...release};
        if (scenario === 'release-race' && releaseReads > 1) data.updateTime = 'unexpected';
      } else if (endpoint.includes('/rulesets/')) {
        data = {source: mode === '--candidate' && scenario !== 'wrong-candidate'
          ? {files: [{name: 'candidate/firestore.rules', content: fs.readFileSync(path.join(directory, 'candidate/firestore.rules'), 'utf8')}]}
          : oldSource};
      } else if (endpoint.endsWith('/collectionGroups/-/indexes')) {
        data = {indexes: mode === '--preflight' || scenario === 'missing' ? [] : [index]};
        if (scenario === 'extra-index') data.indexes.push({...index, name: index.name + '-other'});
      } else if (endpoint.endsWith('/collectionGroups/-/fields')) {
        data = read('backup/fields.published.json');
      } else throw Error('UNEXPECTED_NETWORK_TARGET');
      return {data};
    }}; }
  }};
  return originalLoad.call(this, name, parent, isMain);
};
process.argv = [process.execPath, path.join(directory, 'read-published.cjs'), mode];
require(process.argv[1]);
`;

for (const [mode, scenario, valid, expectedError] of [
  ['--preflight', 'baseline', true],
  ['--preflight', 'wrong-project', false, 'PROJECT_MISMATCH'],
  ['--preflight', 'release-race', false, 'RELEASE_CHANGED_DURING_READ'],
  ['--ready', 'missing', false, 'INDEX_SET_NOT_EXACTLY_APPROVED'],
  ['--ready', 'creating', false, 'INDEX_NOT_READY'],
  ['--ready', 'ready', true],
  ['--ready', 'extra-index', false, 'INDEX_SET_NOT_EXACTLY_APPROVED'],
  ['--candidate', 'published', true],
  ['--candidate', 'wrong-candidate', false, 'PUBLISHED_SOURCE_HASH_MISMATCH'],
  ['--rollback', 'keep-index', true],
]) {
  test(`${mode} ${scenario}: ${valid ? 'accepted' : 'rejected'}`, () => {
    const result = spawnSync(process.execPath, ['-e', fakeMetadataProcess, __dirname, mode, scenario], {
      encoding: 'utf8', timeout: 15000,
    });
    assert.equal(result.error, undefined);
    assert.equal(result.status, valid ? 0 : 1, result.stdout + result.stderr);
    const output = JSON.parse(valid ? result.stdout : result.stderr);
    assert.equal(output.firebaseWrites, 0);
    if (valid) {
      assert.equal(output.applicationDocumentsRead, 0);
      assert.deepEqual(output.metadataMethods, ['GET']);
    } else assert.equal(output.check, expectedError);
  });
}
