// Read-only backend audit. Never deploys or accesses application documents.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { GoogleAuth } = require('../../functions/node_modules/google-auth-library');

const projectId = 'calmatea-4c781';
const output = path.join(__dirname, 'published-2026-10-31');
const hashes = {};
let endpoint;

function save(name, value) {
  const bytes = typeof value === 'string' ? value : `${JSON.stringify(value, null, 2)}\n`;
  const destination = path.join(output, name);
  // Exclusive creation: a second audit must not overwrite the first backup.
  fs.writeFileSync(destination, bytes, { flag: 'wx' });
  hashes[name] = crypto.createHash('sha256').update(bytes).digest('hex');
}

async function main() {
  const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const client = await auth.getClient();
  async function get(url) {
    const allowed = [
      `https://firebase.googleapis.com/v1beta1/projects/${projectId}`,
      `https://firebaserules.googleapis.com/v1/projects/${projectId}/`,
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)`,
    ];
    if (!allowed.some((prefix) => url.startsWith(prefix))) throw new Error('UNEXPECTED_TARGET');
    endpoint = url;
    return (await client.request({ url, method: 'GET' })).data;
  }
  async function listAll(url, key) {
    const values = [];
    let pageToken;
    do {
      const pageUrl = new URL(url);
      if (pageToken) pageUrl.searchParams.set('pageToken', pageToken);
      const page = await get(pageUrl.href);
      values.push(...(page[key] || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    return { [key]: values };
  }

  const project = await get(`https://firebase.googleapis.com/v1beta1/projects/${projectId}`);
  if (project.projectId !== projectId) throw new Error('PROJECT_MISMATCH');
  const root = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)`;
  const database = await get(root);
  const release = await get(`https://firebaserules.googleapis.com/v1/projects/${projectId}/releases/cloud.firestore`);
  if (!release.rulesetName?.startsWith(`projects/${projectId}/rulesets/`)) throw new Error('RULESET_PROJECT_MISMATCH');
  const ruleset = await get(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`);
  const indexes = await listAll(`${root}/collectionGroups/-/indexes`, 'indexes');
  const fields = await listAll(`${root}/collectionGroups/-/fields?filter=indexConfig.usesAncestorConfig%3Dfalse`, 'fields');
  const finalRelease = await get(`https://firebaserules.googleapis.com/v1/projects/${projectId}/releases/cloud.firestore`);
  if (finalRelease.rulesetName !== release.rulesetName || finalRelease.updateTime !== release.updateTime) {
    throw new Error('RELEASE_CHANGED_DURING_AUDIT');
  }
  if (process.argv.includes('--verify')) {
    const previous = (name) => JSON.parse(fs.readFileSync(path.join(output, name), 'utf8'));
    assert.deepEqual(release, previous('release.json'), 'PUBLISHED_RELEASE_CHANGED');
    assert.deepEqual(ruleset.source, previous('ruleset.json').source, 'PUBLISHED_RULES_CHANGED');
    assert.deepEqual(indexes, previous('indexes.published.json'), 'PUBLISHED_INDEXES_CHANGED');
    assert.deepEqual(fields, previous('fields.published.json'), 'PUBLISHED_FIELD_INDEX_POLICY_CHANGED');
    console.log(JSON.stringify({ projectId, publishedRulesAndIndexesUnchanged: true, applicationDocumentsRead: 0, firebaseWrites: 0 }));
    return;
  }
  if (fs.existsSync(output)) throw new Error('BACKUP_ALREADY_EXISTS');
  fs.mkdirSync(output, { recursive: true });
  save('project.json', project);
  save('database.json', database);
  save('release.json', release);
  save('ruleset.json', ruleset);
  const files = ruleset.source?.files || [];
  if (files.length !== 1 || typeof files[0].content !== 'string') throw new Error('UNEXPECTED_RULES_SOURCE');
  save('firestore.rules', files[0].content);
  save('indexes.published.json', indexes);
  save('fields.published.json', fields);
  const deploymentIndexes = {
    indexes: indexes.indexes.filter((index) => index.queryScope === 'COLLECTION' || index.queryScope === 'COLLECTION_GROUP').map((index) => ({
      collectionGroup: index.name.split('/collectionGroups/')[1].split('/')[0],
      queryScope: index.queryScope,
      fields: index.fields.filter((field) => field.fieldPath !== '__name__'),
      ...(index.density ? { density: index.density } : {}),
    })),
    // __default__/* is the database's built-in index policy, not an override
    // to redeploy. Its exact server response is retained in fields.published.json.
    fieldOverrides: fields.fields.filter((field) => field.indexConfig && !field.indexConfig.usesAncestorConfig && !field.name.includes('/collectionGroups/__default__/')).map((field) => ({
      collectionGroup: field.name.split('/collectionGroups/')[1].split('/')[0],
      fieldPath: field.name.split('/fields/')[1],
      indexes: (field.indexConfig.indexes || []).map((index) => ({ queryScope: index.queryScope, ...index.fields?.find((entry) => entry.fieldPath !== '__name__') })).map(({ fieldPath, ...index }) => index),
    })),
  };
  save('firestore.indexes.json', deploymentIndexes);
  save('manifest.json', {
    projectId,
    capturedAtUtc: new Date().toISOString(),
    releaseName: release.name,
    rulesetName: release.rulesetName,
    releaseUpdateTime: release.updateTime,
    remoteMethods: ['GET'],
    applicationDocumentsRead: 0,
    files: hashes,
  });
  console.log(JSON.stringify({ projectId, releaseName: release.name, rulesetName: release.rulesetName, updateTime: release.updateTime, indexes: indexes.indexes.length, fieldOverrides: deploymentIndexes.fieldOverrides.length, backup: output, rulesSha256: hashes['firestore.rules'] }, null, 2));
}

main().catch((error) => {
  // Never print auth clients, requests, headers, tokens, or credential objects.
  console.error(JSON.stringify({ audit: 'failed', endpoint, status: error.response?.status || null, code: error.response?.data?.error?.status || error.code || error.message, apiMessage: error.response?.data?.error?.message }));
  process.exitCode = 1;
});
