import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { requireAddons } from "./addons.js";
import { ROOT } from "./config.js";

// Match the editor's XML association; override when the export lives elsewhere.
const configuredSchema = process.env.WOW_UI_SCHEMA;
const schema = resolve(
  ROOT,
  configuredSchema ?? "E:/Projects/InterfaceExport/_files/wow_classic_beta/Interface/AddOns/Blizzard_SharedXML/UI.xsd",
);
if (!existsSync(schema)) {
  if (configuredSchema !== undefined) throw new Error(`WOW_UI_SCHEMA does not point to an existing file: ${schema}`);
  console.log(`XML validation skipped: schema not found at ${schema}. Set WOW_UI_SCHEMA to the exported UI.xsd path.`);
  process.exit(0);
}

const script = [
  "from pathlib import Path",
  "from lxml import etree",
  "import sys",
  "schema = etree.XMLSchema(etree.parse(sys.argv[1]))",
  // Vendored libraries under lib/ are third-party code, like for LuaLS, StyLua and Prettier.
  "files = [p for root in sys.argv[2:] for p in Path(root).rglob('*.xml') if 'lib' not in p.relative_to(root).parts]",
  "failed = []",
  "for path in files:",
  "    doc = etree.parse(str(path))",
  "    if not schema.validate(doc): failed.append(f'{path}: {schema.error_log.last_error}')",
  "print(f'XML schema OK ({len(files)} files)' if not failed else '\\n'.join(failed))",
  "raise SystemExit(1 if failed else 0)",
].join("\n");

const result = spawnSync("python", ["-c", script, schema, ...requireAddons().map((addon) => addon.path)], {
  encoding: "utf-8",
});
if (result.error) {
  if ((result.error as NodeJS.ErrnoException).code === "ENOENT")
    throw new Error("python was not found; it is required for XML validation");
  throw result.error;
}
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
process.exit(result.status ?? 1);
