---
id: data
title: Data and integrity
description: Named datasets, checksums, locked data, and the integrity ledger
section: features
position: 2
---

## Named datasets

[fw_use](ref:fw_use) and [fw_save](ref:fw_save) take a name or a file path. A name resolves in this order:

1. **A file path.** Anything with a slash or a known extension, such as `inputs/raw/visits.csv`. Relative paths are tried from the current folder, then from the project root. `fw_use` uses the current folder when the file is there. `fw_save` uses it when the file or its folder is there. Otherwise both use the project root, so `fw_save "outputs/tables/x.csv"` from `notebooks/` writes to the project's `outputs/tables`.
2. **The data catalog.** An entry under `data` in the settings, such as `inputs.raw.survey`.
3. **Dot notation.** The longest leading part that names a project folder picks the folder. The rest names the file. `inputs.final.analysis` is `$fw_inputs_final/analysis.dta`.

```stata
fw_use inputs.raw.survey, clear
fw_save inputs.final.analysis, replace
fw_use "inputs/raw/visits.csv", clear options(varnames(1))
```

`fw_save` creates the folder when needed. It does not edit the data catalog. R and Python find the dataset by its path.

### Data catalog

The catalog is the same one R and Python read.

```yaml
data:
  inputs:
    raw:
      survey:
        path: inputs/raw/survey.csv
        type: csv
        locked: true
```

### File types

| Extension | Read with | Written with |
|-----------|-----------|--------------|
| `.dta` | `use` | `save` |
| `.csv`, `.tsv` | `import delimited` | `export delimited` |
| `.xlsx`, `.xls` | `import excel, firstrow` | `export excel` |

`options()` passes options to the Stata command.

## Integrity checks

`fw_save` records two fingerprints of a named dataset:

- **SHA-256** of the file. It comes from `sha256sum` or `shasum` on Linux and macOS and from PowerShell on Windows. All three ship with the system.
- **`datasignature`** of the data. It covers values and variable names. It does not cover labels or notes.

`fw_use` compares the file checksum before loading and the data signature after. Without a SHA-256 tool, only the data signature is checked.

### Locked datasets

A changed dataset is handled by its lock:

- **Locked** stops with error 459.
- **Unlocked** loads with a warning and updates the record.

`fw_save` locks a dataset unless you add `unlocked`. A catalog entry with `locked: true` is locked too. A name first seen by `fw_use` is recorded unlocked.

```stata
fw_save inputs.raw.cars, replace
fw_save inputs.final.analysis, replace unlocked
```

To accept a change to a locked dataset, check it, then load it with `check(accept)`. It records the new checksum, data signature, and time. The lock stays as it was. The file is not rewritten, so a CSV or Excel file keeps its original bytes.

```stata
fw_use inputs.raw.cars, clear check(accept)
```

`check(accept)` needs a catalog or dot name. On an unchanged dataset it does nothing. `check(warn)` loads a changed dataset once with a warning and keeps the old record, so the next strict `fw_use` stops again. `check(off)` skips the check and the record.

### Records

Records live in `.framework/stata-integrity.tsv`, one row per name: the path, checksum, data signature, lock, size, and time. Plain file paths are not recorded. Use a catalog or dot name to track a file.

R and Python keep their records in `framework.db`, which Stata cannot read. Each language checks its own records.

## Integrity ledger

With the ledger on, `fw_save` and `fw_use, check(accept)` also send the checksum, the file size, and this computer's name to Framework Cloud. The data itself is never uploaded.

```yaml
default:
  options:
    cloud_ledger: live
```

`FW_LEDGER=off` in the environment turns it off for a session. Sending uses the project token in the project's `.env` file. See [Framework Cloud](guide:cloud).

## Stored results

Both commands store `r(name)`, `r(path)`, `r(type)`, `r(sha256)`, `r(datasignature)`, and `r(locked)`. `fw_use` also stores `r(accepted)`: 1 when `check(accept)` recorded the dataset again.
