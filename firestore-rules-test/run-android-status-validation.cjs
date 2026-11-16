'use strict';

// Test-only, loopback TCP gate. disableNetwork() does not reliably block native
// Android transaction RPCs; this gate physically closes their transport instead.
const net = require('node:net');
const http = require('node:http');
const path = require('node:path');
const { spawn } = require('node:child_process');
const assert = require('node:assert/strict');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-calmatea-local');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');

let online = true;
const sockets = new Set();
const gate = net.createServer((incoming) => {
  if (!online) { incoming.destroy(); return; }
  const upstream = net.connect({ host: '127.0.0.1', port: 8080 });
  sockets.add(incoming);
  sockets.add(upstream);
  incoming.on('error', () => upstream.destroy());
  upstream.on('error', () => incoming.destroy());
  incoming.on('close', () => { sockets.delete(incoming); upstream.destroy(); });
  upstream.on('close', () => { sockets.delete(upstream); incoming.destroy(); });
  incoming.pipe(upstream);
  upstream.pipe(incoming);
});
const control = http.createServer((request, response) => {
  if (request.method !== 'POST' || !['/pause', '/resume'].includes(request.url)) {
    response.writeHead(404).end(); return;
  }
  online = request.url === '/resume';
  if (!online) for (const socket of sockets) socket.destroy();
  console.log(`Local transaction transport: ${online ? 'online' : 'offline'}`);
  response.writeHead(204).end();
});
function listen(server, port) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
}
function cleanup() {
  for (const socket of sockets) socket.destroy();
  gate.close();
  control.close();
}
async function main() {
  try {
    await listen(gate, 8090);
    await listen(control, 8091);
    const args = [
      'test', 'integration_test/firebase_emulator_android_test.dart', '-d', 'emulator-5554',
      '--dart-define=USE_FIREBASE_EMULATORS=true',
      '--dart-define=ENABLE_ACTIVITY_EXECUTION=true',
      '--dart-define=ENABLE_ACTIVITY_PREVIEW=false',
      '--dart-define=ENABLE_EXECUTION_HISTORY=true',
      '--dart-define=ENABLE_EXECUTION_METRICS=true',
      '--dart-define=FIRESTORE_TEST_PROXY_PORT=8090',
      '--dart-define=FIRESTORE_TEST_PROXY_CONTROL_PORT=8091',
    ];
    const child = spawn('flutter', args, { cwd: path.resolve(__dirname, '..'), stdio: 'inherit', shell: process.platform === 'win32' });
    process.exitCode = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('exit', (code) => resolve(code ?? 1));
    });
  } finally { cleanup(); }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; cleanup(); });
