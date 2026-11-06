# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml", "jsonschema"]
# ///
"""Build the docs site for stata.framework.pub.

Writes docs/site/reference.json from docs/site/reference.yml, checks it,
and packs docs-site.tar.gz (one top folder, docs-site/) for framework-cloud:

    python3 scripts/build_docs.py      # re-runs itself with uv when PyYAML is missing
    uv run scripts/build_docs.py

Then, in framework-cloud: php artisan fw:docs-import stata ../framework-stata/docs-site.tar.gz

The full schema check uses docs-reference.v1.json from a framework-cloud
checkout next to this one, or the file FW_DOCS_SCHEMA names, when present.
"""

import json
import os
import re
import shutil
import sys
import tarfile
from pathlib import Path

try:
    import yaml
except ImportError:
    if shutil.which("uv") and not os.environ.get("FW_BUILD_DOCS_REEXEC"):
        os.environ["FW_BUILD_DOCS_REEXEC"] = "1"
        os.execvp("uv", ["uv", "run", "--quiet", "--script", __file__, *sys.argv[1:]])
    sys.exit("build_docs.py needs PyYAML. Run it with: uv run scripts/build_docs.py")

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "docs" / "site"
ARCHIVE = ROOT / "docs-site.tar.gz"
PRODUCT = "stata"
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
ENTRY_KEYS = {
    "id", "name", "kind", "category", "title", "summary", "usage", "description", "details",
    "parameters", "returns", "note", "sections", "examples", "see_also", "aliases", "lifecycle",
    "replaced_by", "since",
}


def version() -> str:
    text = (ROOT / "ado" / "fw_core.mata").read_text()
    m = re.search(r'fw_version\(\)\s*return\("([^"]+)"\)', text)
    if not m:
        sys.exit("Could not find fw_version() in ado/fw_core.mata.")
    return m.group(1)


def strip(value):
    """Trailing newlines from YAML block scalars, recursively."""
    if isinstance(value, str):
        return value.rstrip("\n")
    if isinstance(value, list):
        return [strip(v) for v in value]
    if isinstance(value, dict):
        return {k: strip(v) for k, v in value.items()}
    return value


def check(reference: dict) -> list[str]:
    problems = []
    categories = {c.get("id") for c in reference["categories"]}
    seen = set()
    for c in reference["categories"]:
        for key in ("id", "title", "position"):
            if key not in c:
                problems.append(f"category {c.get('id', '?')} has no {key}.")
    for e in reference["entries"]:
        eid = e.get("id", "?")
        for key in ("id", "name", "kind", "category", "summary"):
            if not e.get(key):
                problems.append(f"entry {eid} has no {key}.")
        if not ID.match(str(eid)):
            problems.append(f"entry id {eid} is not URL-safe.")
        if eid in seen:
            problems.append(f"entry {eid} appears twice.")
        seen.add(eid)
        if e.get("category") not in categories:
            problems.append(f"entry {eid} is in unknown category {e.get('category')}.")
        if e.get("kind") not in ("function", "class", "command"):
            problems.append(f"entry {eid} has kind {e.get('kind')}.")
        extra = set(e) - ENTRY_KEYS
        if extra:
            problems.append(f"entry {eid} has unknown fields: {', '.join(sorted(extra))}.")
        for p in e.get("parameters", []):
            if not p.get("name") or not p.get("description"):
                problems.append(f"entry {eid} has a parameter without a name or description.")
    names = {e["name"] for e in reference["entries"]}
    for c in reference["categories"]:
        for name in c.get("common", []):
            if name not in names:
                problems.append(f"category {c['id']} lists {name} as common, but there is no such entry.")
    return problems


def schema_check(reference: dict) -> str:
    path = os.environ.get("FW_DOCS_SCHEMA") or str(
        ROOT.parent / "framework-cloud" / "resources" / "schema" / "docs-reference.v1.json"
    )
    if not Path(path).is_file():
        return "skipped (no docs-reference.v1.json found)"
    try:
        import jsonschema
    except ImportError:
        return "skipped (jsonschema is not installed)"
    schema = json.loads(Path(path).read_text())
    products = schema["properties"]["product"].get("enum", [])
    note = ""
    if PRODUCT not in products:
        schema["properties"]["product"]["enum"] = [*products, PRODUCT]
        note = f" (the schema does not list {PRODUCT} yet; checked as if it did)"
    errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(reference), key=lambda e: list(e.path))
    if errors:
        for err in errors:
            print(f"  {'/'.join(map(str, err.path)) or '(top)'}: {err.message}", file=sys.stderr)
        sys.exit("reference.json does not match docs-reference.v1.json.")
    return "passed" + note


def main() -> None:
    site = yaml.safe_load((SITE / "site.yml").read_text())
    if site.get("product") != PRODUCT:
        sys.exit(f"docs/site/site.yml must say product: {PRODUCT}.")

    source = yaml.safe_load((SITE / "reference.yml").read_text())
    reference = {
        "schema": "docs-reference.v1",
        "product": PRODUCT,
        "version": version(),
        "categories": strip(source["categories"]),
        "entries": strip(source["entries"]),
    }
    problems = check(reference)
    if problems:
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        sys.exit("reference.yml has problems.")
    schema = schema_check(reference)

    (SITE / "reference.json").write_text(json.dumps(reference, indent=2, ensure_ascii=False) + "\n")

    guides = sorted((SITE / "guides").glob("*.md"))
    for g in guides:
        if not g.read_text().startswith("---\n"):
            sys.exit(f"{g.relative_to(ROOT)} has no front matter.")

    def add(tar: tarfile.TarFile, path: Path, name: str) -> None:
        tar.add(path, arcname=name, recursive=False)

    with tarfile.open(ARCHIVE, "w:gz") as tar:
        add(tar, SITE, "docs-site")
        for name in ("site.yml", "reference.json"):
            add(tar, SITE / name, f"docs-site/{name}")
        add(tar, SITE / "guides", "docs-site/guides")
        for g in guides:
            add(tar, g, f"docs-site/guides/{g.name}")
        images = SITE / "images"
        if images.is_dir():
            files = sorted(p for p in images.rglob("*") if p.is_file() and not p.name.startswith("."))
            if files:
                add(tar, images, "docs-site/images")
            for p in files:
                add(tar, p, f"docs-site/images/{p.relative_to(images).as_posix()}")

    print(f"reference.json: {len(reference['entries'])} entries in {len(reference['categories'])} categories, version {reference['version']}")
    print(f"Schema check: {schema}")
    print(f"Guides: {len(guides)}")
    print(f"Wrote {ARCHIVE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
