import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { syncLocales } from "../sync-locales.js";
import { requireAddons, walkFiles } from "../addons.js";
import { ROOT } from "../config.js";

// StyLua may use either quote style for lookups. Check the migrated suite against
// the actual English catalogue, including labels in infrequently opened panels.
const english = readFileSync(resolve(ROOT, "Seamless/locales/enUS.lua"), "utf8");
const keys = new Set([...english.matchAll(/^L\[("(?:\\.|[^"\\])*")\]/gm)].map((match) => JSON.parse(match[1]!)));
for (const addon of requireAddons()) {
  for (const path of walkFiles(addon.path)) {
    if (!path.endsWith(".lua") || /[/\\](lib|locales)[/\\]/.test(path)) continue;
    for (const match of readFileSync(path, "utf8").matchAll(/L\[("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\]/g)) {
      const key = match[1]!.slice(1, -1).replace(/\\([\\"'nrt])/g, (_, char: string) => {
        return ({ n: "\n", r: "\r", t: "\t" } as Record<string, string>)[char] ?? char;
      });
      assert(keys.has(key), `${path}: missing English key ${key}`);
    }
  }
}

const directory = mkdtempSync(resolve(tmpdir(), "seamless-locales-"));
try {
  const baseline = resolve(directory, "enUS.lua");
  const target = resolve(directory, "deDE/strings.lua");
  writeFileSync(baseline, '-- Common / shared\nL["Open"] = true\n\n-- Frames\nL["Player"] = "Player"\n');
  syncLocales(directory, ["deDE"]);
  let generated = readFileSync(target, "utf8");
  assert.match(generated, /NewLocale\("Seamless", "deDE"\)/);
  assert.match(generated, /if not L then\n {4}return\nend/);
  assert.match(generated, /-- L\["Open"\] = "Open"/);
  writeFileSync(target, generated.replace('-- L["Open"] = "Open"', 'L["Open"] = "Öffnen"'));
  writeFileSync(
    baseline,
    '-- Common / shared\nL["Accept"] = true\n\n-- Frames\nL["Player"] = "Player"\nL["Open"] = true\n',
  );
  syncLocales(directory, ["deDE"]);
  generated = readFileSync(target, "utf8");
  assert.match(generated, /L\["Open"\] = "Öffnen"/);
  assert(generated.indexOf('L["Player"]') < generated.indexOf('L["Open"]'));
  syncLocales(directory, ["deDE"]);
  assert.equal(readFileSync(target, "utf8"), generated, "Synchronization must be idempotent");
  writeFileSync(baseline, '-- Common / shared\nL["Accept"] = true\n');
  assert.throws(() => syncLocales(directory, ["deDE"]), /remove obsolete keys explicitly/);
  assert.equal(readFileSync(target, "utf8"), generated, "Never silently discard a translation");
  writeFileSync(baseline, '-- Common / shared\nL["Accept"] = true\nL["Accept"] = true\n');
  assert.throws(() => syncLocales(directory, ["deDE"]), /Duplicate English key/);
  console.log(
    "PASS: locale creation, guards, stubs, translation preservation, ordering, idempotence and obsolete/duplicate protection",
  );
} finally {
  rmSync(directory, { recursive: true, force: true });
}
