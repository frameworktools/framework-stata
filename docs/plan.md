# Framework for Stata: plan

Status: first version built and tested on JHPCE, 2026-11-05. Nothing is
committed or published.

## Changes from the reviewed draft

Erik asked to push the core as far as Stata and Mata allow, so a user needs no
Python. The build differs from the draft below in these ways:

- **Settings:** Mata reads `settings.yml` directly, with split files and
  environments. There is no settings cache, and no cache writers in R,
  Python, or `fw`. `settings.do` from `fw new --lang stata` is read too.
- **Checksums:** SHA-256 comes from `sha256sum`, `shasum`, or PowerShell,
  which ship with each operating system. `fw hash` was not needed.
- **Integrity record:** `.framework/stata-integrity.tsv`.
- **Estimates:** the mapping lives in Mata (`ado/fw_estimates.mata`), as
  recommended. `fw` needed no estimates input.
- **Publishing:** Stata builds `framework.bundle/v1` bundles and runs the
  folder driver itself, and uploads to Framework Cloud with curl. `fw` and
  framework-py are only needed for GitHub Pages and S3.
- **Login:** Stata runs the browser approval flow with curl. A shell or
  PowerShell script handles the token, so it never enters Stata. framework-py
  and R gained the same flow as `cloud_login()` with no token. `fw` needed no
  `--open` flag.
- **Backend selection:** `auto` uses the core for folders, Cloud, and login,
  then `fw`, then framework-py for GitHub and S3.
- **Packaging:** `net install` keeps only Stata file types, so the two
  Cloud scripts and the reader template ship as `.ihlp` files.
- **Cloud approval page:** `/device` is public. It names the requesting
  program, offers sign-in and account creation, carries the code through
  email links, comes before the passkey prompt, and codes last 20 minutes.
- **Framework Cloud:** accepts `source.language: "stata"` and labels it.

The rest of this document is the reviewed draft.

The package is called `framework`. It gives Stata users the same Framework
workflow as R and Python: project paths, named datasets with integrity checks,
publishing, typed estimation results, and Cloud login.

## Decisions on record

- Build on the local publish-driver work in all four repositories: bundles,
  named destinations, and the `cloud`, `github`, `folder`, and `s3` drivers.
- Core needs Stata 14. Tests run on Stata 17 under `version 14`. A static check
  rejects commands added after Stata 14 in core files.
- Commands use the `fw_` prefix. The SSC archive has no `fw_*` packages and no
  `framework` package. Its only `fw*` packages are `fwer1stage` and `fwtdgen`.
  Stata itself ships no `fw_*` commands.
- The settings cache is committed to git.
- Core integrity uses `datasignature`. This is a Stata-only convention.
- Login uses the browser approval flow from R, Python, and Stata. The approval
  page must work for people without an account.
- The live Cloud test uses the throwaway instance on the framework-selfhost VM.

## Commands

| Command | Purpose | Backend |
|---|---|---|
| `fw_setup` | Check Stata, Python, framework-py, and `fw`. Print next steps. | none |
| `fw_set` | Set or show package options, e.g. `fw_set backend python`. | none |
| `fw_project` | Find the project root. Set path globals. | none |
| `fw_use` | Load a named dataset. Check its integrity. | optional |
| `fw_save` | Save a named dataset. Record its integrity. | optional |
| `fw_publish` | Publish a file or the current estimation results. | required |
| `fw_login` | Connect this computer to Framework Cloud. | required |
| `fw_logout` | Remove the stored Cloud token. | required |

Each command has a `.sthlp` file. `help framework` gives an overview.

### Syntax

```stata
fw_setup
fw_set backend {auto|python|cli|core}
fw_set                                   // show current options
fw_project [, root(path) quietly]

fw_use  name [, clear check(strict|warn|off|accept)]
fw_save name [, replace unlocked]

fw_publish filename [, slug(str) title(str) description(str) to(dest)
                      visibility(public|unlisted|private) private]
fw_publish , estimates [slug(str) title(str) description(str) to(dest)
                      visibility(...) level(#) saving(path [, replace])]

fw_login  [, url(str)]
fw_logout [, url(str)]
```

- `private` confirms a path that contains "private". It maps to
  `include_private=True` in framework-py and `--include-private` in `fw`.
- `saving()` keeps a copy of `model.json`. Without it, the file is temporary.
- `unlocked` matches `locked = FALSE` in R and Python. Datasets are locked
  by default.

### Named datasets

`fw_use inputs.raw.survey` looks up `survey` in the settings catalog. A name
missing from the catalog resolves like `data_save` in R and Python: the
longest leading match to a directory key picks the folder, and the remainder
is the file name. `inputs.intermediate.clean` becomes
`$fw_inputs_intermediate/clean.dta`.

The file extension picks the reader and writer:

| Extension | Load | Save |
|---|---|---|
| `.dta` (default) | `use` | `save` |
| `.csv`, `.tsv` | `import delimited` | `export delimited` |
| `.xlsx`, `.xls` | `import excel, firstrow` | `export excel, firstrow(variables)` |

Other formats produce an error that names the supported ones.

## Project discovery and globals

`fw_project` walks up from `c(pwd)`, at most 10 levels. It stops at the first
folder with `.framework/`, `settings.yml`, `config.yml`, or `settings.do`.
This is the union of the R, Python, and `fw` rules.

It then reads `.framework/settings.stata` and sets:

- `$fw_root`: the project root, absolute, with forward slashes.
- `$fw_<key>` for each directory key, e.g. `$fw_inputs_raw`,
  `$fw_outputs_figures`, `$fw_outputs_public_tables`.
- `$fw_data` and `$fw_outputs` as short aliases. They point at
  `inputs_final` and `outputs` when those folders exist.

The `fw_` prefix keeps these apart from the bare globals in `fw`-generated
`settings.do` files, such as `$inputs_raw`. `fw_project` never overwrites
those.

Other commands call `fw_project` themselves when `$fw_root` is empty.

## Settings cache

Stata can't parse YAML. Framework writes a flat cache that Stata can read
with `file read`.

**File:** `.framework/settings.stata`. It is committed to git, so a
core-only user needs no backend.

**Format:** UTF-8 text, one tab-separated key and value per line, and
`#` for comments. Keys are the dotted settings paths. Values are literal
strings. Lists are not supported. Nothing is evaluated.

```
# framework settings cache v1. Generated. Do not edit.
#source	settings.yml	crc=2034987123	size=1840
#generator	framework-py 0.9.0
project.name	example-study
security.sensitive	false
directories.inputs_raw	inputs/raw
directories.inputs_final	inputs/final
directories.outputs_figures	outputs/figures
data.inputs.raw.survey.path	inputs/raw/survey.csv
data.inputs.raw.survey.type	csv
data.inputs.raw.survey.locked	true
publish.default	lab
publish.destinations.lab.driver	folder
publish.destinations.lab.visibility	private
options.cloud_ledger	live
```

**Contents.** The cache holds `project.name`, `security.sensitive`,
`directories.*`, the `data` catalog, `publish.default`, the driver and
visibility of each destination, and `options.cloud_ledger`. Values resolve
the active environment and split files the same way `settings_read` does.

**Secrets.** `env()` and `!expr` values are never resolved into the cache.
They are written as the literal text `<env:VAR>` and skipped by Stata.
Publish credentials and `.env` values never appear.

**Staleness.** The `#source` line records the CRC and size of
`settings.yml`. Stata computes both with the built-in `checksum` command.
When they differ, Stata warns and prints the regeneration command for the
backends that are available. Split files are covered by an extra `#source`
line for each.

**Writers:**

| Writer | When |
|---|---|
| framework-py | `settings_write`, `data_add`, `data_save`, `new_project`. New `settings_export_stata()`. |
| R | The same points. New `settings_export_stata()`. |
| `fw` | `fw new --lang stata`, and a new `fw settings export --stata`. |
| Stata | `fw_save` adds catalog entries in core mode. See below. |

A shared conformance fixture pins the exact output. It covers a settings file,
split files, and environments, with the expected cache. All three
implementations test against it, as the repositories do for scaffolding now.

`fw` has no YAML settings reader today. The exporter needs one for
directories, `data`, and `publish`, with split files and environments. This is
the largest Go addition.

**Stata-native projects.** `fw new --lang stata` writes `settings.do` and no
`settings.yml` unless publishing is configured. The scaffold will also write
`.framework/settings.stata` from the same spec. `settings.do` keeps working
unchanged.

## Integrity

| Mode | Check | Record |
|---|---|---|
| Core | `datasignature` (data-level) | `.framework/integrity.stata` |
| CLI | SHA-256 of the file via `fw hash` | `.framework/integrity.stata` |
| Python | SHA-256 via framework-py | `framework.db`, plus the Cloud ledger when live |

- `fw_save` saves the file, then records it. A backend adds the SHA-256. Core
  adds only the `datasignature`.
- `fw_use` compares before loading. A locked dataset that changed stops with
  error 459. An unlocked one warns. The same rules as R and Python.
- `.framework/integrity.stata` is tab-separated: name, path, SHA-256 (or
  empty), `datasignature`, locked, recorded time. Stata reads and writes it.
  Under the Python backend, `framework.db` is the record. The Stata file then
  only holds the `datasignature`.
- A core-mode `fw_save` of a new name appends a catalog entry to the cache
  and warns that `settings.yml` lacks it. The warning names the backend
  command that writes it. Core mode never edits YAML.
- The ledger needs the Python backend. It sends metadata and checksums only,
  as R and Python do.

`datasignature` covers values and variable names, not the file bytes. It
catches changed data, not changed labels or notes. The help file says so.

## Backends

### Selection

`fw_set backend` stores the choice in the user config folder:
`<config>/stata.conf`, where `<config>` follows framework-py's `config_dir()`
(`FW_CONFIG_HOME`, then the platform default). The global `$FW_BACKEND`
overrides the stored choice for one session.

With `auto` (the default), the first command that needs a backend resolves it
once per session:

1. **Python** when Stata is 16 or newer, `python query` shows a configured
   Python, and `import framework` succeeds with framework-py at or above the
   minimum version.
2. **CLI** when `fw` is on the PATH and `fw version` reports at least the
   minimum version.
3. **Core** otherwise.

A forced backend that fails stops with an error. It never falls back to
another backend. Commands that need a backend fail in core mode with the exact
fix:

```
fw_publish needs the Python or CLI backend.
  Python: "/usr/bin/python3.12" -m pip install framework-py
  CLI:    install fw from https://framework.pub/docs/cli
Run fw_setup for details.
```

The Python path in that message is the one `python query` reports.

Resolving the Python backend initializes Stata's Python for the session.
Stata can't undo that, so `fw_setup` says so before it runs the check.

### Python backend

framework-py gains a `framework.stata` module. Stata calls it with
`python: from framework import stata`. Stata passes arguments through `sfi`
macros, not by building code strings, so paths and titles need no escaping.

| Function | Use |
|---|---|
| `settings_cache(root)` | Write `.framework/settings.stata`. |
| `data_check(name, path, locked)` | Hash and compare without loading the data. |
| `data_record(name, path, locked)` | Wrap `data_add`: hash, `framework.db`, ledger, catalog. |
| `model_document(raw)` | Build `model.json` from Stata estimation results. |
| `publish(path, **opts)` | Call `publish` and return the receipt as JSON. |
| `login_start(url)` / `login_finish(handle)` | Run the browser approval flow in two steps. |
| `logout(url)` | Wrap `cloud_logout`. |

Results return to Stata as `r()` values through `sfi.Macro` and
`sfi.Scalar`. Errors raise `FrameworkError`. Stata turns the message into an
error with a fixed return code.

### CLI backend

Stata runs `fw ... --json`, sends stdout and stderr to temporary files, and
reads them back. Exit codes map to Stata errors: 3 means not logged in, 6
means a private path. On Unix it uses `shell`. On Windows it uses `winexec`
with a `.cmd` wrapper that writes a done file, and Stata polls for it, so no
console window flashes.

Additions to `fw`:

- `fw settings export --stata [DIR]`
- `fw hash FILE --json` returns `{path, bytes, sha256}`.
- `fw publish` reads `model.json` as today. It needs no estimates flag if
  the model is built before `fw` runs. See the open question below.
- `fw login --json --open` opens the browser without a terminal. It already
  prints the code as JSON on stderr.

JSON parsing in Stata is minimal. Mata reads only the flat keys the package
needs, such as `url`, `version`, `sha256`, and `error`.

## Estimation results

### Flow

1. `fw_publish, estimates` checks that `e(cmd)` is set and `e(b)` and `e(V)`
   exist.
2. Mata collects the values below into a neutral record and writes it as
   JSON.
3. The mapping turns that record into `model.json`
   (`schema: "framework.artifact/v1"`, `kind: "model"`).
4. The backend publishes `model.json`. Bundles pick up `kind` and
   `representation` from the file, as they do for R and Python.

### Open question: where the mapping lives

The brief puts the mapping in framework-py. The CLI backend then needs a
second copy in Go, kept in sync by shared fixtures.

**Recommendation:** write the mapping once, in Mata. Every backend then
publishes identical output. `fw` needs no estimates input. Core mode can
write `model.json` locally with `saving()`. framework-py and `fw` test that
they accept and render the Stata fixtures. The cost: the mapping lives in a
third language, apart from R and Python. Choose one before the code starts.

### Common mapping

| `model.json` | Stata source |
|---|---|
| `source` | `{language: "stata", class: [e(cmd)]}` |
| `model.response` | `e(depvar)` |
| `term` | Column names of `e(b)`. `_cons` becomes `(Intercept)`. Base and omitted factor levels (`b.`, `o.`) are dropped. Multi-equation models use `"<eq>: <term>"`. A single main equation drops its prefix. |
| `estimate`, `std_error` | `e(b)` and the square root of the diagonal of `e(V)` |
| `statistic`, `p_value` | `b/se`. A t-test when `e(df_r)` exists, otherwise normal. |
| `conf_low`, `conf_high` | Wald interval at `level()`, default `c(level)` |
| `confidence_level` | `level()/100` |
| `interval_method` | `wald-t` when `e(df_r)` exists, otherwise `wald-normal` |
| `nobs` | `e(N)` |
| `aic`, `bic` | `estat ic`, run quietly. Skipped where it is invalid. |
| `log_likelihood` | `e(ll)` |
| `vcov_type` | `e(vcetype)`, or `e(vce)` when that is empty |
| `command` | `e(cmdline)`, labeled "Command" |

Estimates stay on the model scale. `exponentiate` tells the reader to offer a
ratio view, as in R and Python. Under `logistic`, `e(b)` is on the log-odds
scale, so no special case is needed.

### Model-specific mapping

| Command | `model` | Extra metrics and tables |
|---|---|---|
| `regress` | linear, gaussian, identity | `df_model` `e(df_m)`, `df_resid` `e(df_r)`, `r.squared` `e(r2)`, `adj.r.squared` `e(r2_a)`, `sigma` `e(rmse)` |
| `logit`, `logistic` | glm, binomial, logit, "Odds ratio" | `pseudo_rsquared` `e(r2_p)`, `llnull` `e(ll_0)` |
| `probit` | glm, binomial, probit | `pseudo_rsquared`, `llnull` |
| `poisson` | glm, poisson, log, "Rate ratio" | `pseudo_rsquared`, `llnull` |
| `nbreg` | glm, negative binomial, log, "Rate ratio" | `alpha` `e(alpha)`. The `/lnalpha` row leaves the coefficient table. |
| `glm` | glm. Family from `e(varfuncf)`, link from `e(linkf)`, mapped to R names. "Odds ratio" or "Rate ratio" by the R rules. | `deviance` `e(deviance)`, `dispersion` `e(dispers)`, `df_resid` `e(df)` |
| `mixed` | mixed, gaussian, identity | Fixed effects from the `e(depvar)` equation. A random-effects table: `group`, `term`, `variance`, `std_dev`, `correlation`. Rebuilt from the `lns*`, `atr*`, and `lnsig_e` parameters with `e(ivars)`, `e(revars)`, and `e(vartypes)`. `n_groups.<var>` from `e(N_g)`, `reml`, `sigma`. |
| `stcox` | survival, "Hazard ratio" | No intercept. `n_events` `e(N_fail)`. `response` is `_t`. |
| `ivregress` | linear, gaussian, identity | `estimator` `e(estimator)`, `instrumented` `e(instd)`, `instruments` `e(insts)`, `r.squared`, `sigma` `e(rmse)`. A t-test only with `small`. |

- `mixed` covers the independent, identity, exchangeable, and unstructured
  covariance structures. Other structures, and non-iid residuals, publish
  the fixed effects only, with a warning.
- Any other `e(cmd)` that has `e(b)` and `e(V)` publishes as type `other`
  with a coefficient table and a warning. Survey (`svy`) results publish this
  way in the first version.

### Fixtures

The tests pin one golden `model.json` per command, from `sysuse auto`,
`webuse` copies shipped as test data, and synthetic data. Cloud and the
offline reader tests use the same files.

## Cloud login

### Flow

1. `fw_login` prints the consent notice that R, Python, and `fw` print.
2. The backend starts the device flow:
   `POST /api/v1/cli/device {client_name: "Stata on <host>"}`.
3. Stata prints the code and the approval URL, then opens the browser with
   `view browse`. In batch mode it prints them only.
4. The backend polls until the request is approved, denied, or expired. It
   checks the token with `/api/v1/me` and stores it in the system keyring
   under the shared service `framework-cloud:<host>`, account `token`.
5. Stata prints the account name. The token never passes through Stata
   macros, the Results window, or a log.

The CLI backend runs `fw login --json --yes --open` in the background. Stata
reads the code from stderr as it arrives and polls for the exit code.

### framework-py and R

`cloud_login()` with no token runs the browser flow in both packages. Passing
a token keeps working as it does today. framework-py exposes the two steps
for Stata. R gets the single-call form only.

### Framework Cloud: the approval page for new users

Today a signed-out visitor to `/device` lands on the bare sign-in page. A
sign-up whose email link opens on another device loses the request. The
passkey and welcome screens come before the approval, and the 10-minute code
can expire during sign-up.

Changes:

- `/device` is reachable signed out. It names the requesting program and the
  code, then offers **Sign in** and **Create account**. Both carry the code.
- The pending code travels with the magic link and the GitHub OAuth state.
  The approval survives a link opened in another browser.
- After sign-in, `/device` comes first. The passkey prompt and the welcome
  screen come after approval.
- Device codes last 20 minutes. An expired code shows the command to run
  again.
- With registration closed, the page says so and offers sign-in only.

`PasskeyPromptController.php` already has uncommitted changes from other work.
I'll coordinate before editing it.

### Framework Cloud: Stata models

- Accept `source.language: "stata"` (`ArtifactRepresentation.php:40`).
- Label it "Stata" in the viewer (`documents/show.blade.php:90`) and in the
  offline reader.
- Match `_cons` as an intercept in the forest plot, as a safeguard. Stata
  already renames it.
- Add the Stata fixtures to the artifact display tests.

## Private paths

Stata applies the shared rule itself before it calls a backend. A full path
that contains "private", in any case, needs confirmation. The macOS
`/private/` system prefix is ignored. Paths resolve against `c(pwd)`.

- Interactive Stata lists the flagged paths and asks for `y` through
  `display _request()`.
- Batch mode stops with error 198 and names the `private` option.
- After confirmation, Stata passes `include_private=True` or
  `--include-private`. The backend never asks a second time.

## Coordination with the General Cloud thread

Both threads share the `~/Projects/framework-cloud` checkout. Nothing is
committed.

- **This thread:** `/device` and its sign-in, magic-link, GitHub OAuth, and
  `PasskeyPromptController` flow; `ArtifactRepresentation.php`;
  `documents/show.blade.php`; the static reader; the artifact display tests.
- **General Cloud thread:** language dropdowns and "scaffolding only" copy
  (`library.js`, `Welcome.vue`, `Settings/Defaults.vue`,
  `Blueprints/Index.vue`, `Projects/Create.vue`, `Projects/Show.vue`,
  `Tokens.vue`, `LanguageTabs.vue`); `landing-*.blade.php` and
  `site-header.blade.php`; `docs/guide/*.md`, including `stata.md`;
  `resources/schema/*.json`; the comments in `app/Models/Project.php`.
- Command names and syntax changes go into this file first. The other thread
  follows it.

## Repository layout

```
framework-stata/
  framework.pkg  stata.toc  README.md  LICENSE
  ado/   fw_*.ado, _fw_*.ado helpers, fw_*.sthlp, framework.sthlp
  mata/  fw_json.mata, fw_estimates.mata  (compiled to lfw.mlib at install)
  examples/  01-project.do  02-data.do  03-publish.do  04-estimates.do
  tests/  run.do  core/  python/  cli/  fixtures/  check_version14.py
  docs/  plan.md  jhpce.md
```

Install from a checkout: `net install framework, from("<dir>") replace`.

## Testing

### Stata

`tests/run.do` runs every test file and prints a pass/fail summary. Each test
builds a temporary project under `c(tmpdir)`. Layers:

- **Core:** discovery, globals, the cache reader, staleness, named datasets,
  `datasignature` checks, private-path rules, and `model.json` output for each
  command against the golden fixtures.
- **CLI:** `fw hash`, `fw publish` to a `folder` destination, the error and
  exit-code mapping, and the cache export.
- **Python:** the same scenarios through framework-py, plus `framework.db`.
- **Live Cloud:** one publish and one login, run separately. The token is
  read from a mode-600 file. The tests never print it.

### framework-py, `fw`, R, Cloud

Each repository gets tests for its additions: the cache writer against the
shared fixture, `framework.stata`, the device login, `fw hash`,
`fw settings export`, `--open`, the Stata model fixtures, and the approval
page states.

### JHPCE

- Use `stata/17` on compute nodes only, through `srun`.
- Cross-compile `fw` for linux/amd64 and copy it to `~/bin`.
- Use Python 3.11+ in a venv under `$HOME`, with framework-py installed from
  this checkout and set with `python set exec`.
- Read the logs back over SSH. `docs/jhpce.md` records the steps and results.
- Windows, macOS, and `winexec` can't be tested there. The report says so.

## Order of work

1. Core: discovery, cache reader, globals, datasets, `datasignature`.
2. The settings cache writers in framework-py, `fw`, and R, with the shared
   fixture.
3. The estimates mapping and golden fixtures.
4. The Python backend and `framework.stata`.
5. The CLI backend and the `fw` additions.
6. Login: framework-py, R, `fw --open`, and the Cloud approval page.
7. Cloud acceptance of Stata models.
8. Help files, examples, README.
9. JHPCE runs and report.

## Out of scope for the first version

- SSC submission and a GitHub repository.
- `svy`-specific output, `margins`, and multiple-imputation estimates.
- Parquet and SAS or SPSS formats.
- Writing YAML from core Stata.
- `fw_publish` for folders and notebooks.
