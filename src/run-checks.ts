import { spawn } from "node:child_process";
import { ROOT } from "./config.js";

export interface Check {
  name: string;
  command: string;
  args: string[];
}

/** Independent processes, bounded concurrency, grouped logs, and no skipped checks on failure. */
export async function runChecks(checks: Check[], concurrency: number): Promise<boolean[]> {
  if (!Number.isInteger(concurrency) || concurrency < 1) throw new Error("Concurrency must be a positive integer");
  const results: boolean[] = [];
  let next = 0;
  const worker = async () => {
    while (next < checks.length) {
      const index = next++;
      const check = checks[index]!;
      results[index] = await new Promise<boolean>((resolve) => {
        const start = performance.now();
        let output = "";
        const child = spawn(check.command, check.args, { cwd: ROOT, windowsHide: true });
        child.stdout.setEncoding("utf8").on("data", (data: string) => (output += data));
        child.stderr.setEncoding("utf8").on("data", (data: string) => (output += data));
        child.on("error", (error) => (output += `${error.message}\n`));
        child.on("close", (code) => {
          console.log(
            `\n--- ${check.name}: ${code === 0 ? "PASS" : "FAIL"} (${((performance.now() - start) / 1000).toFixed(2)}s) ---`,
          );
          if (output) process.stdout.write(output.endsWith("\n") ? output : `${output}\n`);
          resolve(code === 0);
        });
      });
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrency, checks.length) }, worker));
  return results;
}
