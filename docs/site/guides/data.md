---
id: data
title: Data and integrity
description: Named datasets, SHA-256 checksums, locked entries, the Cloud ledger, tables, and figures
section: features
position: 2
---

## Named datasets

[fw_use](ref:fw_use) and [fw_save](ref:fw_save) resolve dataset identifiers in three steps:

1. **File path.** Any string containing a slash or a supported file extension, such as `inputs/raw/visits.csv`. `fw_use` checks relative to the current directory first and falls back to the project root. `fw_save` uses the current directory when the target file or parent folder exists there, and otherwise resolves from the project root.
2. **Data catalog entry.** A key under `data` in `settings.yml` or `settings/data.yml`, such as `inputs.raw.survey`.
3. **Dot notation.** The longest prefix matching a configured directory key selects the directory, and the remainder names a `.dta` file. For example, `inputs.final.analysis` resolves to `$fw_inputs_final/analysis.dta`.

```stata
fw_use inputs.raw.survey, clear
fw_save inputs.final.analysis, replace
fw_use "inputs/raw/visits.csv", clear options(varnames(1))
```

`fw_save` creates missing parent directories automatically. It does not modify `settings.yml`; R and Python resolve saved files by path or existing catalog entries.

### Data catalog

Stata reads the same `data` catalog structure used by R and Python:

```yaml
data:
  inputs:
    raw:
      survey:
        path: inputs/raw/survey.csv
        type: csv
        locked: true
```

### Supported file formats

| Extension | Reader | Writer |
|---|---|---|
| `.dta` | `use` | `save` |
| `.csv`, `.tsv` | `import delimited` | `export delimited` |
| `.xlsx`, `.xls` | `import excel, firstrow` | `export excel` |

Pass native Stata reader or writer flags through `options()`.

### CSV and TSV compatibility

`fw_use` aligns delimited imports with R's `data_read()` so shared catalog files produce consistent values across languages:

- **Missing values.** Empty cells and `NA` strings import as missing values. Columns containing only numbers and `NA` import as numeric. Pass custom missing tokens with `na()`, such as `na("NA" "-99")`. Pass `na("")` to preserve literal `"NA"` text.
- **Double precision.** Decimal columns import with `asdouble` so `75.2` remains `75.2` rather than `float` `75.19999695`. Add `asfloat` to use Stata's `float` default.
- **Column renaming.** Stata restricts variable names to 32 characters without spaces. When `import delimited` shortens or alters a header beyond lowercasing, `fw_use` prints the old and new names and preserves the original header as the variable label. Pass `options(case(preserve))` to preserve uppercase characters.

`TRUE` and `FALSE` remain string values in Stata.

To assign explicit Stata variable names to long CSV headers, set `stata_names` on the catalog entry:

```yaml
data:
  inputs:
    raw:
      visits:
        path: inputs/raw/visits.csv
        stata_names:
          reason_ecmoref_refpicu_any_cardiac: reason_cardiac
          log1p_bchecmoref_to_bchadmit_days: log1p_days
```

`fw_use inputs.raw.visits` renames those columns to `reason_cardiac` and `log1p_days`. Exporting back to CSV or TSV with `fw_save inputs.raw.visits` restores the original file headers so R and Python scripts continue reading the unchanged column names. R and Python ignore `stata_names`.

## Integrity checks

`fw_save` records two fingerprints for each dataset:

- **SHA-256 file checksum**, computed with `sha256sum` or `shasum` on Linux and macOS and PowerShell on Windows.
- **Stata `datasignature`**, covering cell values and variable names (excluding variable labels and dataset notes).

`fw_use` checks the SHA-256 hash before loading and the `datasignature` after loading. If no SHA-256 utility is available, Stata checks `datasignature` alone.

### Locked datasets

Lock status determines how `fw_use` handles modified files:

- **Locked entries** stop with error 459.
- **Unlocked entries** load with a warning and update the stored fingerprint.

`fw_save` saves datasets unlocked unless `lock` is passed. Catalog entries with `locked: true` are also locked. Datasets first recorded by `fw_use` without `locked: true` start unlocked.

```stata
fw_save inputs.raw.cars, replace
fw_save inputs.final.analysis, replace lock
```

### Locked data protection

`fw_save` does not change locked data, matching `data_save()` in R and Python. Saving the same data again works and keeps the lock: the same data has the `datasignature` in the integrity record, and the file still matches the record's SHA-256. New data stops with error 608 before writing, by catalog name or file path:

```text
fw_save does not overwrite locked data.
  dataset: inputs.raw.cars (saved locked)
  file:    inputs/raw/cars.dta
Save the data under another name, or add the unlock option to replace it.
The new file is then unlocked. Add the lock option to keep it locked.
```

Save derived data under another name. To replace locked data on purpose, add `unlock`. The new file is unlocked unless `lock` is also passed. Setting `locked: false` on a catalog entry also unlocks it. `fw_table` does not overwrite locked data either.

```stata
fw_save inputs.raw.cars, replace unlock lock
fw_save inputs.intermediate.cars, replace unlock
```

To accept an intentional update to a locked dataset without rewriting its bytes, load it once with `check(accept)`:

```stata
fw_use inputs.raw.cars, clear check(accept)
```

`check(accept)` requires a catalog or dot name and updates the stored SHA-256 hash, `datasignature`, and timestamp while keeping the lock active. `check(warn)` loads a modified locked file once with a warning while leaving the prior checksum in place. `check(off)` bypasses verification and recording.

### Integrity records

Stata stores fingerprints in `.framework/stata-integrity.tsv` with the dataset name, relative path, SHA-256 hash, `datasignature`, lock flag, byte size, and timestamp. Saving to a plain file path records the file under its project-relative path, matching R's `data_save()`. Plain path reads via `fw_use` skip integrity verification; use catalog or dot names for verified reads.

R and Python store integrity records in `framework.db`, which Stata does not read. Each language verifies its own integrity store.

## Integrity ledger

When the Cloud integrity ledger is live, `fw_save` and `fw_use, check(accept)` send the dataset name, SHA-256 checksum, byte size, and computer hostname to Framework Cloud. Dataset contents are never uploaded.

```yaml
default:
  options:
    cloud_ledger: live
```

Set `FW_LEDGER=off` in the environment to disable ledger uploads for a session. Ledger requests authenticate with `FW_PROJECT_TOKEN` in `.env`. See [Framework Cloud](guide:cloud).

## Tables and figures

[fw_table](ref:fw_table) saves the data in memory, or a matrix, to the tables folder. [fw_graph](ref:fw_graph) exports a graph to the figures folder. They match `save_table()` and `save_figure()` in R and Python. A name may include subfolders, such as `meeting/table-1`, which are created. A name ending in a file type, such as `weight.svg`, picks that type.

### Output folders

Tables go to `outputs_tables`, else `outputs/tables`. Figures go to `outputs_figures`, else `outputs/figures`. A project with `security: sensitive: true`, or with `outputs_private_*` or `outputs_public_*` folders, splits private and public outputs. Files go to the private folder unless `public` is passed:

```stata
fw_table counts make price            // outputs/private/tables/counts.csv
fw_table counts make price, public    // outputs/public/tables/counts.csv
fw_graph price-mpg, public            // outputs/public/figures/price-mpg.png
```

Without a configured folder, the split uses `outputs/private/<kind>` and `outputs/public/<kind>`. A public table made from data in a file with `private` in its path prints a warning.

### Table options

Headers default to each variable's label, else its name. `varnames` uses names. `headers()` gives one header per column, in order; a count mismatch stops with error 198. `nolabel` writes value codes instead of value labels. `na()` sets the text for missing numbers in CSV, `NA` by default; `na("")` leaves cells empty. `format(csv xlsx)` writes both file types; the default is CSV. The data in memory are not changed.

```stata
sysuse auto, clear
fw_table summary make price mpg
fw_table "meeting/table-1" make price if foreign, headers("Model" "Price, USD") format(csv xlsx)
```

CSV files follow R's `write_csv()`: `NA` for missing numbers, value labels as text, dates as `2026-11-07`, and quotes only where needed.

`matrix()` saves a matrix instead of the data in memory, with its column names as headers. Row names other than Stata's defaults (`r1`, `r2`, ...) become a first column with an empty header:

```stata
matrix M = (1, 2.5 \ 3, .)
matrix rownames M = mpg weight
matrix colnames M = b se
fw_table coefs, matrix(M)
```

```text
,b,se
mpg,1,2.5
weight,3,NA
```

`headers()` also names the row-name column: `fw_table coefs, matrix(M) headers("Term" "Estimate" "SE")`.

### Figure options

`fw_graph` exports the current graph, or the graph named in `name()`. `format()` lists file types, such as `format(png pdf)`; the default is PNG. Raster files (PNG, TIFF, JPEG, GIF) are `dpi()` pixels per inch of the graph's width, 300 by default, so a graph 5.5 inches wide gives a PNG 1,650 pixels wide. `width()` or `height()` sets the raster size in pixels instead. `options()` passes options to `graph export`.

```stata
sysuse auto, clear
scatter mpg price
fw_graph price-mpg
fw_graph "meeting/price-mpg", format(png pdf)
fw_graph small, width(400)
scatter mpg weight, name(byweight, replace)
fw_graph weight.svg, name(byweight)
```

### Replacement

Both commands overwrite an existing file by default; `replace` states this explicitly. `noreplace` stops with error 602 when the file exists. `fw_table` stops with error 608 instead of overwriting locked data, such as a file saved with `fw_save`.

### Results log

Each file is recorded in `.framework/stata-results.tsv` by its path from the project root, with its type (`table` or `figure`), public flag, SHA-256 checksum, byte size, and creation and update times. Saving the same file again updates its row. R and Python record the same fields in `framework.db`.

Both commands store `r(path)` (the first file), `r(paths)`, `r(sha256)` (the first file's checksum), `r(format)`, and `r(public)`. `fw_table` adds `r(N)` and `r(k)`, the rows and columns written.

## Stored results

Both `fw_use` and `fw_save` store `r(name)`, `r(path)`, `r(type)`, `r(sha256)`, `r(datasignature)`, and `r(locked)`. `fw_use` adds `r(accepted)` (`1` when `check(accept)` updated the record).
