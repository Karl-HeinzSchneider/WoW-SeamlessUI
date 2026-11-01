import { spawnSync } from "node:child_process";
import { relative } from "node:path";
import { requireAddons, walkFiles } from "./addons.js";
import { ROOT } from "./config.js";

const files = requireAddons()
  .flatMap((addon) => walkFiles(addon.path))
  .filter((path) => path.endsWith(".lua"));
const failures: string[] = [];

function compile(paths: string[]) {
  const result = spawnSync("luac", ["-p", ...paths.map((path) => relative(ROOT, path))], {
    cwd: ROOT,
    encoding: "utf-8",
    windowsHide: true,
  });
  if (result.error) {
    if ((result.error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error("luac was not found; install a Lua 5.1 compiler to run check:lua");
    }
    throw result.error;
  }
  return result;
}

// Small batches avoid command-line and Lua 5.1 combined-chunk limits, while keeping every file.
// Retry failed batches individually to report every bad file and avoid combined-chunk false failures.
for (let offset = 0; offset < files.length; offset += 32) {
  const batch = files.slice(offset, offset + 32);
  if (compile(batch).status === 0) continue;
  for (const file of batch) {
    const result = compile([file]);
    if (result.status !== 0) failures.push(`${relative(ROOT, file)}: ${(result.stderr || result.stdout).trim()}`);
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`Lua syntax OK (${files.length} files)`);
