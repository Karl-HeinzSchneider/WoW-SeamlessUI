import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { CLIENT_LOCALES, ROOT } from "./config.js";

// Deliberately a small, line-based format: one quoted key/value assignment per line.
// Never evaluate translator-provided Lua in the tooling process.
const assignment = /^(--\s*)?L\[("(?:\\.|[^"\\])*")\]\s*=\s*("(?:\\.|[^"\\])*"|true)\s*$/;
export function syncLocales(
  directory = resolve(ROOT, "Seamless/locales"),
  locales: readonly string[] = CLIENT_LOCALES,
): void {
  const baseline = readFileSync(resolve(directory, "enUS.lua"), "utf8");
  const body = baseline.slice(baseline.indexOf("-- Common / shared")).trimEnd().split(/\r?\n/);
  const keys = new Set<string>();
  for (const line of body) {
    const match = assignment.exec(line);
    if (match) {
      if (keys.has(match[2]!)) throw new Error(`Duplicate English key: ${match[2]}`);
      keys.add(match[2]!);
    } else if (line.trim() && !line.startsWith("-- ")) {
      throw new Error(`Unsupported English locale line: ${line}`);
    }
  }
  if (!keys.size) throw new Error("English locale has no entries");

  for (const locale of locales) {
    const folder = resolve(directory, locale);
    const path = resolve(folder, "strings.lua");
    const translations = new Map<string, string>();
    if (existsSync(path)) {
      const seen = new Set<string>();
      for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
        const match = assignment.exec(line);
        if (match) {
          if (seen.has(match[2]!)) throw new Error(`${locale}: duplicate key ${match[2]}`);
          seen.add(match[2]!);
          if (!match[1]) translations.set(match[2]!, line);
        } else if (line.trimStart().startsWith("L[")) {
          throw new Error(`${locale}: unsupported assignment; use one quoted value per line: ${line}`);
        }
      }
    }
    const obsolete = [...translations.keys()].filter((key) => !keys.has(key));
    if (obsolete.length) throw new Error(`${locale}: remove obsolete keys explicitly: ${obsolete.join(", ")}`);
    const header = [
      "-- Ordered by npm run locales:sync. Uncomment entries to translate; missing values use English.",
      `local L = LibStub("AceLocale-3.0"):NewLocale("Seamless", "${locale}")`,
      "if not L then",
      "    return",
      "end",
      "",
    ];
    // enUS uses the baseline already loaded by the TOC. AceLocale normalizes enGB to enUS.
    const lines = body.map((line) => {
      const match = assignment.exec(line);
      return match
        ? (translations.get(match[2]!) ?? `-- L[${match[2]}] = ${match[3] === "true" ? match[2] : match[3]}`)
        : line;
    });
    mkdirSync(folder, { recursive: true });
    writeFileSync(path, [...header, ...lines, ""].join("\n"));
  }
  console.log(`Synchronized ${locales.length} locale files (${keys.size} keys).`);
}

if (resolve(process.argv[1] ?? "") === fileURLToPath(import.meta.url)) syncLocales();
