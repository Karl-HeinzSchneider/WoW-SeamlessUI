import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { ROOT } from "../config.js";
import { runChecks, type Check } from "../run-checks.js";

const directory = mkdtempSync(resolve(tmpdir(), "seamless checks "));
const node = (name: string, code: string, ...args: string[]): Check => ({
  name,
  command: process.execPath,
  args: ["-e", code, ...args],
});
try {
  // Both processes must start before either can finish. A sequential runner fails the barrier.
  const barrier = `
    const fs = require('node:fs');
    fs.writeFileSync(process.argv[1], 'started');
    const timeout = setTimeout(() => process.exit(1), 10000);
    const poll = setInterval(() => {
      if (fs.existsSync(process.argv[2])) { clearTimeout(timeout); clearInterval(poll); }
    }, 10);
  `;
  const a = resolve(directory, "a");
  const b = resolve(directory, "b");
  assert.deepEqual(await runChecks([node("barrier A", barrier, a, b), node("barrier B", barrier, b, a)], 2), [
    true,
    true,
  ]);

  // With one worker, a failure or missing executable must not skip a queued check.
  const marker = resolve(directory, "after failure");
  assert.deepEqual(
    await runChecks(
      [
        node("expected failure", "process.exit(7)"),
        { name: "missing executable", command: resolve(directory, "missing-executable"), args: [] },
        node("after failure", "require('node:fs').writeFileSync(process.argv[1], 'done')", marker),
      ],
      1,
    ),
    [false, false, true],
  );
  assert.equal(readFileSync(marker, "utf8"), "done");
  await assert.rejects(runChecks([], 0));

  // Run the real Lua checker in an isolated miniature repository with paths containing spaces.
  mkdirSync(resolve(directory, "src"));
  writeFileSync(resolve(directory, "package.json"), '{"type":"module"}');
  for (const file of ["check-lua.ts", "addons.ts", "config.ts"]) {
    copyFileSync(resolve(ROOT, "src", file), resolve(directory, "src", file));
  }
  const addon = resolve(directory, "Fixture");
  mkdirSync(addon);
  writeFileSync(resolve(addon, "Fixture.toc"), "");
  for (let i = 0; i < 70; i++) {
    writeFileSync(resolve(addon, `${String(i).padStart(3, "0")}.lua`), "return 1\n");
  }
  const checkLua = () =>
    spawnSync(
      process.execPath,
      [resolve(ROOT, "node_modules/tsx/dist/cli.mjs"), resolve(directory, "src/check-lua.ts")],
      {
        encoding: "utf8",
        timeout: 30000,
      },
    );
  let result = checkLua();
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Lua syntax OK \(70 files\)/);
  // Errors in the first and final batch must both be reported.
  writeFileSync(resolve(addon, "001.lua"), "local =\n");
  writeFileSync(resolve(addon, "069.lua"), "local =\n");
  result = checkLua();
  assert.ifError(result.error);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /001\.lua/);
  assert.match(result.stderr, /069\.lua/);
  console.log("PASS: concurrent execution, failure propagation, queued checks, and batched Lua syntax coverage");
} finally {
  rmSync(directory, { recursive: true, force: true });
}
