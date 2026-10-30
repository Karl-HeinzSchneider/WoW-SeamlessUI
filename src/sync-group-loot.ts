import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { ROOT } from "./config.js";

// Preserve upstream source inside a function so WoW can pass an isolated private
// table to it without changing upstream bindings or sharing Core's namespace.
const repository = process.argv[2];
if (!repository) throw new Error("Usage: tsx src/sync-group-loot.ts <repository> [ref]");
const ref = process.argv[3] ?? "origin/main";
const commit = execFileSync("git", ["-C", repository, "rev-parse", `${ref}^{commit}`], { encoding: "utf8" }).trim();
const read = (path: string) =>
  execFileSync("git", ["-C", repository, "show", `${commit}:${path}`], { encoding: "utf8" });
const target = resolve(ROOT, "Seamless/src/embed/BetterGroupLoot/vendor");
const xml = read("BetterGroupLoot/embedded.xml");
const scripts = [...xml.matchAll(/<Script\s+file="([^"]+)"/g)].map((match) => match[1]!.replaceAll("\\", "/"));
if (scripts.length === 0 || scripts.some((path) => !/^src\/(api|rolls)\/[\w]+\.lua$/.test(path)))
  throw new Error("Review upstream embedded.xml before importing its new load graph");
for (const file of ["embedded.xml", "src/types.lua", ...scripts]) {
  const path = resolve(target, file);
  mkdirSync(dirname(path), { recursive: true });
  const source = read(`BetterGroupLoot/${file}`);
  writeFileSync(
    path,
    scripts.includes(file)
      ? `local addonName, host = ...\nlocal function loadEmbedded(...)\n${source}\nend\nloadEmbedded(addonName, host.groupLoot)\n`
      : source,
  );
}
writeFileSync(resolve(target, "LICENSE"), read("LICENSE"));
writeFileSync(
  resolve(target, "source.json"),
  JSON.stringify(
    { repository: "https://github.com/Karl-HeinzSchneider/WoW-BetterGroupLoot", commit, wrapper: 1 },
    null,
    2,
  ) + "\n",
);
console.log(`Imported BetterGroupLoot ${commit} (${scripts.length} isolated scripts)`);
