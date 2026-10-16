import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Repository layout, relative to this file (src/config.ts). */
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/**
 * Every value of the client's [TextLocale] TOC path variable. The client loads a
 * `locales\[TextLocale]\<file>` entry for its own language only and warns when that file is
 * missing, so check:addons requires it for all of them.
 */
export const CLIENT_LOCALES = [
  "enUS",
  "enGB",
  "deDE",
  "esES",
  "esMX",
  "frFR",
  "itIT",
  "koKR",
  "ptBR",
  "ruRU",
  "zhCN",
  "zhTW",
] as const;

/** Required shared addon, independent of the suite archive name. */
export const CORE_ADDON = "Seamless";

/** `package-as` in .pkgmeta: the suite archive name. */
export function packageName(): string {
  const pkgmeta = readFileSync(resolve(ROOT, ".pkgmeta"), "utf-8");
  const name = /^package-as:\s*(\S+)/m.exec(pkgmeta)?.[1];
  if (!name) throw new Error(".pkgmeta has no package-as line");
  return name;
}

/** Public addon folders listed in our flat .pkgmeta move-folders mapping. */
export function releaseAddonNames(): string[] {
  const pkgmeta = readFileSync(resolve(ROOT, ".pkgmeta"), "utf-8");
  const section = /^move-folders:\s*\r?\n((?:[ \t]+[^\n]*\n|\r?\n)*)/m.exec(pkgmeta)?.[1];
  const names = [...(section ?? "").matchAll(/^  [^\s#][^:\r\n]*: ([A-Za-z0-9_-]+)\s*$/gm)].map((match) => match[1]!);
  if (names.length === 0) throw new Error(".pkgmeta has no release addon folders");
  return names;
}
