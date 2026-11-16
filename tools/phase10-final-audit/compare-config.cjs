'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const backup = path.join(__dirname, 'published-2026-10-31');
const manifest = JSON.parse(fs.readFileSync(path.join(backup, 'manifest.json'), 'utf8'));
for (const [name, hash] of Object.entries(manifest.files)) {
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(backup, name))).digest('hex'), hash, `Backup hash mismatch: ${name}`);
}
const published = fs.readFileSync(path.join(backup, 'firestore.rules'), 'utf8');
const local = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');
function block(source, declaration) {
  const start = source.indexOf(declaration);
  assert.ok(start >= 0, `Missing ${declaration}`);
  let balance = 0;
  const body = source.indexOf('{', start + declaration.length);
  for (let index = body; index < source.length; index++) {
    if (source[index] === '{') balance++;
    if (source[index] === '}' && --balance === 0) return source.slice(start, index + 1);
  }
  throw new Error(`Unclosed ${declaration}`);
}
const legacy = ['users/{uid}', 'psychologists/{uid}', 'children/{childId}', 'therapies/{therapyId}', 'activities/{activityId}'];
const comparisons = legacy.map((collection) => {
  const oldBlock = block(published, `match /${collection}`);
  const newBlock = block(local, `match /${collection}`);
  assert.equal(newBlock, oldBlock, `Existing collection changed: ${collection}`);
  return { collection, byteIdenticalUtf8: true, sha256: crypto.createHash('sha256').update(oldBlock).digest('hex') };
});
for (const helper of ['isAuthenticated()', 'isOwner(uid)']) {
  assert.equal(block(local, `function ${helper}`), block(published, `function ${helper}`));
}
const proposed = path.join(__dirname, 'proposed-2026-10-31');
fs.mkdirSync(proposed, { recursive: true });
for (const name of ['firestore.rules', 'firestore.indexes.json']) {
  const target = path.join(proposed, name);
  const source = fs.readFileSync(path.join(root, name));
  if (fs.existsSync(target)) assert.deepEqual(fs.readFileSync(target), source, 'Proposal changed: requires renewed review');
  else fs.writeFileSync(target, source, { flag: 'wx' });
}
const oldLines = published.replace(/\r\n/g, '\n').split('\n');
const newLines = local.replace(/\r\n/g, '\n').split('\n');
const matrix = Array.from({ length: oldLines.length + 1 }, () => new Uint16Array(newLines.length + 1));
for (let i = oldLines.length - 1; i >= 0; i--) for (let j = newLines.length - 1; j >= 0; j--) matrix[i][j] = oldLines[i] === newLines[j] ? matrix[i + 1][j + 1] + 1 : Math.max(matrix[i + 1][j], matrix[i][j + 1]);
let i = 0, j = 0;
const diff = ['--- published/firestore.rules', '+++ proposed/firestore.rules', `@@ -1,${oldLines.length} +1,${newLines.length} @@`];
while (i < oldLines.length || j < newLines.length) {
  if (i < oldLines.length && j < newLines.length && oldLines[i] === newLines[j]) { diff.push(` ${oldLines[i]}`); i++; j++; }
  else if (j < newLines.length && (i === oldLines.length || matrix[i][j + 1] >= matrix[i + 1][j])) diff.push(`+${newLines[j++]}`);
  else diff.push(`-${oldLines[i++]}`);
}
fs.writeFileSync(path.join(__dirname, 'rules.published-to-proposed.diff'), `${diff.join('\n')}\n`);
const report = {
  projectId: manifest.projectId,
  verifiedBackupFiles: Object.keys(manifest.files).length,
  existingCollections: comparisons,
  existingSharedHelpersIdentical: true,
  publishedIndexConfig: JSON.parse(fs.readFileSync(path.join(backup, 'firestore.indexes.json'), 'utf8')),
  proposedIndexConfig: JSON.parse(fs.readFileSync(path.join(root, 'firestore.indexes.json'), 'utf8')),
  proposedSha256: Object.fromEntries(['firestore.rules', 'firestore.indexes.json'].map((name) => [name, crypto.createHash('sha256').update(fs.readFileSync(path.join(proposed, name))).digest('hex')])),
};
fs.writeFileSync(path.join(__dirname, 'comparison.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
