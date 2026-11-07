"""Write framework.pkg from the files in ado/.

Run after adding or removing a file: python3 scripts/build_pkg.py
"""

from pathlib import Path

root = Path(__file__).resolve().parent.parent
files = sorted(p.name for p in (root / "ado").iterdir() if p.is_file() and not p.name.startswith(".") and p.suffix != ".md")
lines = [
    "v 3",
    "d framework: Framework for Stata",
    "d Project paths, named datasets with integrity checks, publishing of figures,",
    "d tables, documents, and estimation results, and Framework Cloud login.",
    "d The same workflow as the R and Python packages. Core commands need no",
    "d Python; fw and framework-py add GitHub and S3 publishing.",
    "d",
    "d Requires: Stata 14 or newer. curl for Framework Cloud.",
    "d Distribution-Date: 20261107",
    "d Author: Framework contributors",
    "d Support: https://framework.pub",
]
lines += [f"f ado/{name}" for name in files]
(root / "framework.pkg").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"framework.pkg lists {len(files)} files")
