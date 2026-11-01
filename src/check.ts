import { availableParallelism } from "node:os";
import { runChecks } from "./run-checks.js";

const npm = process.env.npm_execpath;
if (!npm) throw new Error("Run this command through npm run check");

const checks = ["typecheck", "check:addons", "check:lua", "check:xml", "format:check"];
const results = await runChecks(
  checks.map((name) => ({ name, command: process.execPath, args: [npm, "run", name] })),
  Math.min(3, availableParallelism()),
);
process.exitCode = results.every(Boolean) ? 0 : 1;
