const { spawnSync } = require("node:child_process");

const scripts = [
  "test:sequence-e2e",
  "test:matching-e2e",
  "test:motor-e2e",
  "test:emotion-e2e",
  "test:drag-drop-e2e",
  "test:pictogram-e2e",
  "test:tracing-e2e",
  "test:timer-e2e",
  "test:professional-history-e2e",
  "test:execution-metrics-e2e",
  "test:phase10-integral-e2e",
];

for (const script of scripts) {
  for (const command of ["seed", script]) {
    const result = spawnSync("npm", ["run", command], {
      cwd: __dirname,
      stdio: "inherit",
      env: process.env,
      shell: process.platform === "win32",
    });
    if (result.error) {
      console.error(result.error);
      process.exit(1);
    }
    if (result.status !== 0) process.exit(result.status ?? 1);
  }
}

console.log(`PHASE 10 E2E PASSED (${scripts.length}): ${scripts.join(", ")}`);
