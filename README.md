# Framework for Stata

Framework gives a research project a standard directory layout, records dataset integrity, and publishes results. This package brings the Framework workflow to Stata alongside the R package, `framework-py`, and the `fw` CLI. All four tools share project settings, the data catalog, and publishing destinations.

| Command | Purpose |
|---|---|
| `fw_setup` | Check Stata, system tools, backends, and the Cloud connection |
| `fw_scaffold` | Load the project and initialize the session |
| `fw_project` | Find the project and set path globals |
| `fw_packages` | List and install project packages |
| `fw_use` | Load a named dataset and verify its integrity |
| `fw_save` | Save a named dataset and record its integrity |
| `fw_table` | Save data in memory or a matrix as a table |
| `fw_graph` | Export a graph to the figures folder |
| `fw_publish` | Publish a figure, table, document, or estimation results |
| `fw_login` | Connect this computer to Framework Cloud |
| `fw_logout` | Remove this computer's Cloud token |
| `fw_set` | Set the backend and the location of `fw` |

## Requirements

- Stata 14 or newer.
- `curl` for Framework Cloud. It ships with macOS, Linux, and Windows 10 or later.

Stata handles projects, datasets, SHA-256 checksums, folder publishing, Cloud publishing, and Cloud authentication natively. Python is unnecessary for core features.

## Installation

```stata
net install framework, from("https://raw.githubusercontent.com/frameworktools/framework-stata/main") replace
fw_setup
```

`fw_setup` reports working components and prints setup steps for missing tools.

To install from a local repository checkout, point `from()` at the checkout directory:

```stata
net install framework, from("/path/to/framework-stata") replace
```

## Quick start

```stata
cd "~/projects/example-study"
fw_scaffold
fw_use inputs.raw.survey, clear
regress outcome treatment age
fw_publish, estimates title("Treatment effect")
```

`fw_publish` uses the project's default destination. Projects without a configured default publish to Framework Cloud using the project token in `.env`. See [Publishing](#publishing) for folder destinations.

The `examples` folder contains five runnable do-files. They load `sysuse auto` in a temporary project and publish to a local folder. `05-cleanup.do` removes the temporary project.

## Projects

`fw_project` searches upward from the current directory to the first directory containing `.framework/`, `settings.yml`, `config.yml`, or `settings.do`. It sets `$fw_root` and one global per project directory, such as `$fw_inputs_raw` and `$fw_outputs_figures`.

Stata reads `settings.yml` directly, including split files such as `settings/data.yml` and environment sections. Plain YAML mappings, lists, and scalars are supported. Anchors, aliases, nested flow collections, and tab indentation stop with an error. Projects created with `fw new --lang stata` also define directory globals in `settings.do`, which `fw_project` reads.

A project can contain both files. `settings.do` defines directory globals for plain Stata scripts. `settings.yml` holds settings shared across Stata, R, Python, and `fw`: `project_name`, `directories`, `packages`, `scaffold`, the data catalog, `publish` destinations, `security`, and `options`. `fw_project` reads `settings.yml` first and adds any `settings.do` directories absent from `settings.yml`. Every Framework command uses that merged configuration. When both files assign different paths to the same directory key, `settings.yml` takes precedence and `fw_project` prints a notice.

### Precision

Stata creates new numeric variables as `float` by default. Commands such as `generate` and `collapse (mean)` on non-`double` variables retain roughly seven significant digits. R and Python compute in double precision, so results can diverge near `1e-7`. Add `set type double` near the top of `master.do` to match R and Python precision:

```stata
version 14
set type double
fw_scaffold
```

The setting applies for the current Stata session. Framework does not change Stata's default storage type automatically. Existing `float` variables remain `float` until converted with `recast double`. `fw_use` imports decimal columns in CSV and TSV files as `double`.

## Packages

`fw_packages` reads the `packages` section of `settings.yml` or `settings/packages.yml`. `fw_packages install` installs missing packages from SSC, GitHub, or a `net` URL. `fw_packages update` reinstalls configured packages.

```yaml
packages:
  project_ado: true
  default_packages:
    - estout
    - sergiocorreia/reghdfe@6.12.3
    - name: mytools
      source: net
      url: https://example.org/stata
```

When `project_ado: true` is set, packages install into `ado/plus` inside the project directory. Commit `ado/plus` to pin exact package code with the project.

## Session setup

`fw_scaffold` initializes the Stata session from project settings. Run it at the top of `master.do`:

```stata
fw_scaffold
```

`fw_scaffold` loads the project, sets `PLUS` to `ado/plus` when `project_ado` is enabled, installs missing packages, applies the random seed and graph scheme from `scaffold:` in `settings.yml`, adds the `functions` directory to the ado-path, and runs `scaffold.do` when present.

```yaml
scaffold:
  seed_on_scaffold: true
  seed: 123
  set_theme_on_scaffold: true
  stata_scheme: s2color
```

## Named datasets and integrity

```stata
fw_save inputs.final.analysis, replace
fw_use inputs.final.analysis, clear
```

`fw_save` records the file's SHA-256 checksum and Stata's `datasignature`. `fw_use` verifies the checksum before loading and the data signature afterward. A modified locked dataset stops with error 459. A modified unlocked dataset prints a warning. `fw_save` saves datasets unlocked unless you specify `lock`. Entries first recorded by `fw_use` are locked only when marked `locked: true` in the catalog.

Saving to a file path records the checksum under its project-relative path. `fw_use` skips integrity checks on plain file paths, matching R's `data_read()`. To accept an intentional change to a locked dataset, run `fw_use <name>, clear check(accept)`. Stata records the updated checksum without rewriting the file.

- SHA-256 hashes use `sha256sum` or `shasum` on Linux and macOS and PowerShell on Windows.
- Integrity records are stored in `.framework/stata-integrity.tsv`. R and Python store records in `framework.db`, which Stata cannot read.
- When `options: cloud_ledger: live` is enabled, `fw_save` and `fw_use, check(accept)` send the checksum, file size, and hostname to Framework Cloud using `FW_PROJECT_TOKEN` from `.env`. Dataset rows are never uploaded.

`fw_use` imports CSV and TSV files with R-compatible defaults: empty cells and `NA` become missing values, and decimal columns import as `double`. When Stata renames a column (for example, names exceeding 32 characters), `fw_use` lists the old and new names. Set `stata_names` on a catalog entry to map long file headers to chosen Stata variable names; `fw_save` restores the original headers when exporting CSV or TSV files. See `help fw_use` for `na()` and `asfloat`.

## Tables and figures

```stata
fw_table "meeting/table-1" group n pct, headers("Group" "Patients" "Share, %")
scatter mpg price
fw_graph price-mpg, format(png pdf)
```

`fw_table` and `fw_graph` match `save_table()` and `save_figure()` in R and Python. They write to the project's tables and figures directories, create nested subdirectories automatically, and record each output file with its SHA-256 checksum in `.framework/stata-results.tsv`. Table headers use variable labels or explicit `headers()` strings. `fw_table` also exports Stata matrices. In privacy-sensitive projects, both commands write to private output directories unless `public` is specified.

## Publishing

```stata
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
regress price mpg weight
fw_publish, estimates slug(price-model) to(lab)
```

Publishing destinations are configured in `settings.yml`:

```yaml
publish:
  default: lab
  destinations:
    lab:
      driver: folder
      path: /Volumes/lab/published
      visibility: private
```

| Destination | Handler |
|---|---|
| Local or shared folder | Stata |
| Framework Cloud | Stata (`curl` with `FW_PROJECT_TOKEN` in `.env`) |
| GitHub Pages | `fw` or `framework-py` |
| S3 | `fw` or `framework-py` |

Folder publishing writes the standard `framework.bundle/v1` layout: output files with SHA-256 checksums, an offline HTML reader, and numbered version directories. When `.env` defines a Cloud project token, folder publishing also registers artifact metadata with Framework Cloud while keeping files on local storage.

Passing a directory or wildcard pattern such as `"$fw_outputs_figures/*.png"` publishes all matching files as one multi-file artifact, matching `publish_dir()` in R and Python.

Files whose resolved path contains `private` require confirmation. Interactive Stata prompts before upload. Batch mode stops with error 198 unless `includeprivate` is specified. The `private` option sets artifact visibility (`visibility(private)`).

### Estimation results

`fw_publish, estimates` serializes active estimation results to the shared `model.json` format rendered by Framework Cloud and the offline reader.

| Command | Model type | Ratio view | Additional statistics |
|---|---|---|---|
| `regress` | linear | | R², adjusted R², residual SD |
| `logit`, `logistic` | glm, binomial, logit | odds ratio | pseudo R², null log likelihood |
| `probit` | glm, binomial, probit | | pseudo R² |
| `poisson` | glm, poisson, log | rate ratio | pseudo R² |
| `nbreg` | glm, negative binomial, log | rate ratio | alpha |
| `glm` | glm, family and link from Stata | by link | deviance, dispersion |
| `mixed` | mixed | | random effects, groups, REML |
| `stcox` | survival | hazard ratio | events |
| `ivregress` | linear | | estimator, instruments |

Other estimation commands exposing `e(b)` and `e(V)` publish a generic coefficient table. Estimates remain on the linear predictor scale, `_cons` maps to `(Intercept)`, and base or omitted factor levels are excluded. `mixed` supports independent, identity, exchangeable, and unstructured covariance structures.

## Framework Cloud

```stata
fw_login
```

`fw_login` displays a verification code and opens the browser approval page. Sign in and approve the computer. Stata stores the account token in the system keyring, shared with R, Python, and `fw`. Systems without a keyring store the token in a permission-restricted file under `~/.config/framework`. Tokens never appear in Stata's Results window, macros, or logs; a helper script passes credentials to `curl` via a temporary header file.

`fw_login` authenticates the workstation. Publishing artifacts from a project uses `FW_PROJECT_TOKEN` in the project's `.env` file.

## Backends

GitHub Pages and S3 publishing require an external backend.

- **CLI (`fw`).** Install `fw` from https://cli.framework.pub/guides/install. Stata searches `PATH` and standard installation directories. On macOS, GUI applications inherit a minimal `PATH`; set the binary path explicitly when needed:

  ```stata
  fw_set fw_path "/opt/homebrew/bin/fw"
  ```

- **Python (`framework-py`).** Requires Stata 16 or newer and Python 3.11 or newer. Check Stata's configured Python interpreter:

  ```stata
  python query
  ```

  Install `framework-py` into that interpreter:

  ```sh
  /path/from/python/query -m pip install framework-py
  ```

  Stata requires a Python build with a shared `libpython`. Static cluster builds fail to load; `uv python install 3.11` installs a compatible shared build. Configure the interpreter path and optional virtual environment site-packages in Stata:

  ```stata
  python set exec "/home/me/.local/share/uv/python/cpython-3.11.18-linux-x86_64-gnu/bin/python3.11"
  python set userpath "/home/me/venvs/framework/lib/python3.11/site-packages", prepend
  ```

- **Backend selection.** The default `auto` mode uses native Stata for folder and Cloud targets, then tries `fw` and `framework-py` for GitHub Pages and S3. Pin a backend persistently with `fw_set backend core`, `cli`, or `python`, or per session with `global FW_BACKEND cli`. If a pinned backend is unavailable, Stata stops with setup instructions rather than falling back.

## Tests

```sh
stata -b do tests/run.do
```

The test runner reports pass and fail counts across the core, CLI, and Python test suites. `scripts/jhpce-test.sh` syncs the checkout to a Slurm cluster and runs the suite on a compute node. `docs/jhpce.md` records cluster test runs.

Static checks and packaging scripts:

```sh
python3 scripts/check_version14.py   # verify Stata 14 compatibility
python3 scripts/build_pkg.py         # regenerate framework.pkg
sh -n ado/fw_cloud_sh.ihlp           # check shell script syntax
```

## Repository layout

```text
ado/        commands, help files, Mata sources, and Cloud helper scripts
examples/   runnable example do-files
tests/      run.do, core/, cli/, python/, and fixtures/
scripts/    package builder, Stata 14 syntax checker, and cluster test runner
docs/       site guides, reference source, and test reports
```
