"""Fail when core files use Stata commands added after Stata 14.

The Python backend (python commands) is allowed only in files that check
c(stata_version) >= 16 first. Run: python3 scripts/check_version14.py
"""

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
# Commands and functions introduced in Stata 15, 16, or 17.
NEWER = {
    "frame": "16", "frames": "16", "frget": "16", "frlink": "16", "frput": "16",
    "python": "16", "collect": "17", "table1": "17", "etable": "17", "dtable": "18",
    "putdocx": "15", "putpdf": "15", "unicode": None, "lasso": "16", "meta": "16",
    "bayes": "15", "spregress": "15", "ustrsplit": None, "fileread": None,
}
PYTHON_OK = {"_fw_python.ado", "fw_publish.ado", "fw_setup.ado"}
ALLOWED = {"unicode", "ustrsplit", "fileread"}

problems = []
for path in sorted((root / "ado").glob("*.ado")):
    text = path.read_text(encoding="utf-8")
    if not re.search(r"^\s*version 14\b", text, re.M):
        problems.append(f"{path.name}: missing 'version 14'")
    for number, line in enumerate(text.splitlines(), 1):
        code = line.split("//")[0].strip()
        if code.startswith("*"):
            continue
        for word in re.findall(r"^(?:quietly\s+|capture\s+|noisily\s+)*([A-Za-z_][A-Za-z0-9_]*)", code):
            if word in NEWER and word not in ALLOWED:
                if word == "python" and path.name in PYTHON_OK:
                    continue
                problems.append(f"{path.name}:{number}: '{word}' needs Stata {NEWER[word]}")
for path in sorted((root / "ado").glob("*.mata")):
    text = path.read_text(encoding="utf-8")
    if not re.search(r"^version 14\b", text, re.M):
        problems.append(f"{path.name}: missing 'version 14'")
    # Mata functions added after Stata 14.
    for name in ("_frame", "st_frame", "ustrsplit(", "pathresolve(", "pathlist("):
        if name in text:
            problems.append(f"{path.name}: uses {name}, which needs Stata 16 or newer")
    for bad, why in ((") |> ", "R-style pipes are not Mata"),):
        if bad in text:
            problems.append(f"{path.name}: {why}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print("All core files stay within Stata 14.")
