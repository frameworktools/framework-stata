# Framework for Stata

Framework gives a research project a standard layout, records which data an
analysis used, and publishes results. This package brings the Framework
workflow to Stata, alongside the R and Python packages and the `fw`
command-line tool. All of them share one set of project settings, one data
catalog, and the same publishing destinations.

| Command | Purpose |
|---|---|
| `fw_setup` | Check Stata, system tools, backends, and the Cloud connection |
| `fw_project` | Find the project and set path globals |
| `fw_use` | Load a named dataset and check its integrity |
| `fw_save` | Save a named dataset and record its integrity |
| `fw_publish` | Publish a figure, table, document, or estimation results |
| `fw_login` | Connect this computer to Framework Cloud |
| `fw_logout` | Remove this computer's Cloud token |
| `fw_set` | Set the backend and the location of `fw` |

## Requirements

- Stata 14 or newer.
- curl for Framework Cloud. It ships with macOS, Linux, and Windows 10 or later.

Stata handles projects, datasets, SHA-256 checksums, publishing to a folder or
to Framework Cloud, and Cloud login itself. Python is not needed.

## Install

```stata
net install framework, from("https://raw.githubusercontent.com/frameworktools/framework-stata/main") replace
fw_setup
```

`fw_setup` lists what works and the exact steps for anything missing.

To install from a checkout of this repository, point `from()` at its folder:

```stata
net install framework, from("/path/to/framework-stata") replace
```

## Quick start

```stata
cd "~/projects/example-study"
fw_project
fw_use inputs.raw.survey, clear
regress outcome treatment age
fw_publish, estimates title("Treatment effect")
```

`fw_publish` goes to the project's default destination. A project with no
default goes to Framework Cloud, which needs a project token in `.env`. See
[Publishing](#publishing) for a folder destination.

The `examples` folder has five runnable do-files. They use `sysuse auto` and a
temporary project, and publish to a local folder. `05-cleanup.do` removes the
project.

## Projects

`fw_project` walks up from the current folder to the first folder with
`.framework/`, `settings.yml`, `config.yml`, or `settings.do`. It sets
`$fw_root` and one global per project folder, such as `$fw_inputs_raw` and
`$fw_outputs_figures`.

Stata reads `settings.yml` directly, including split files such as
`settings/data.yml` and environment sections. Plain YAML mappings, lists, and
scalars work. Anchors, aliases, and nested flow collections stop with a clear
error, and so does a tab in the indentation. Projects that `fw new --lang
stata` created keep their folders in `settings.do`, and `fw_project` reads
those too.

## Named datasets and integrity

```stata
fw_save inputs.final.analysis, replace
fw_use inputs.final.analysis, clear
```

`fw_save` records the file's SHA-256 checksum and Stata's `datasignature`.
`fw_use` compares both before and after loading. A changed locked dataset stops
with error 459; an unlocked one warns. `fw_save` locks a dataset unless you add
`unlocked`. A name first recorded by `fw_use` is locked only when the catalog
marks it `locked: true`. Plain file paths are not recorded or checked. To accept
a change to a locked dataset, load it with `fw_use <name>, clear check(accept)`.
It records the new checksum and keeps the file as it is.

- SHA-256 comes from `sha256sum` or `shasum` on Linux and macOS and from
  PowerShell on Windows. All three ship with the operating system.
- Records live in `.framework/stata-integrity.tsv`. R and Python keep theirs in
  `framework.db`, which Stata cannot read.
- With the integrity ledger on (`options: cloud_ledger: live`), `fw_save` and
  `fw_use, check(accept)` send the checksum, the file size, and this
  computer's name to Framework Cloud, using the project token in `.env`. The
  data itself is never uploaded.

## Publishing

```stata
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
regress price mpg weight
fw_publish, estimates slug(price-model) to(lab)
```

Destinations come from the project settings:

```yaml
publish:
  default: lab
  destinations:
    lab:
      driver: folder
      path: /Volumes/lab/published
      visibility: private
```

| Destination | Handled by |
|---|---|
| A folder, such as a shared drive | Stata |
| Framework Cloud | Stata, with curl and the project token in `.env` |
| GitHub Pages | `fw` or framework-py |
| S3 | `fw` or framework-py |

Folder publishing builds the same `framework.bundle/v1` bundle R and Python
build: every file with its checksum, an offline reader, and numbered versions.
With a project token in `.env`, a folder publish also records the artifact's
metadata in Framework Cloud. The files stay in the folder.

A file whose full path contains "private" needs confirmation. Interactive Stata
asks. Batch mode stops until you add the `includeprivate` option. The `private`
option is short for `visibility(private)`.

### Estimation results

`fw_publish, estimates` writes the same `model.json` that R and Python publish.
Framework Cloud and the offline reader show a Stata model like any other.

| Command | Model type | Ratio view | Extras |
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

Other commands with `e(b)` and `e(V)` publish a generic coefficient table.
Estimates stay on the model scale; `_cons` becomes `(Intercept)`; base and
omitted factor levels are left out. `mixed` random effects cover independent,
identity, exchangeable, and unstructured covariance.

## Framework Cloud

```stata
fw_login
```

`fw_login` shows a code and opens the approval page. Sign in, or create a free
account, and approve the computer. The token goes in the system keyring, where
R, Python, and `fw` find it too. Without a keyring, it goes in a private file
in `~/.config/framework`. The token never appears in Stata's Results window,
macros, or logs: a small shell or PowerShell script reads it and hands it to
curl in a private header file.

Publishing a project to Cloud uses the project token in the project's `.env`
file. `fw_login` connects the computer, not a project.

## Backends

GitHub Pages and S3 publishing need one of two backends.

**CLI.** Install `fw` from https://framework.pub/docs/cli. Stata finds it on
the PATH. The Stata application on macOS starts with a short PATH; point to
`fw` when it is not found:

```stata
fw_set fw_path "/opt/homebrew/bin/fw"
```

**Python.** Stata 16 or newer, with framework-py installed in Stata's Python
3.11 or newer:

```stata
python query
```

Then install framework-py with that Python:

```sh
/path/from/python/query -m pip install framework-py
```

Stata needs a Python built with a shared `libpython`. Most installers provide
one. Some cluster modules are static and do not work; `uv python install 3.11`
gives a shared build. Point Stata at the interpreter, and add a virtual
environment's packages with `python set userpath`:

```stata
python set exec "/home/me/.local/share/uv/python/cpython-3.11.18-linux-x86_64-gnu/bin/python3.11"
python set userpath "/home/me/venvs/framework/lib/python3.11/site-packages", prepend
```

**Choice.** `auto`, the default, uses Stata for folders and Cloud, then `fw`,
then framework-py for GitHub and S3. Force one with `fw_set backend core`,
`cli`, or `python`, or for one session with `global FW_BACKEND cli`. A forced
backend that is unavailable stops with the exact fix; it never falls back.

## Tests

```sh
stata -b do tests/run.do
```

The runner prints a pass/fail summary for the core, CLI, and Python layers.
`scripts/jhpce-test.sh` copies the checkout to a Slurm cluster and runs it on a
compute node. `docs/jhpce.md` records the latest results.

Other checks:

```sh
python3 scripts/check_version14.py   # core stays within Stata 14
python3 scripts/build_pkg.py         # regenerate framework.pkg after adding files
sh -n ado/fw_cloud_sh.ihlp           # shell syntax
```

## Repository layout

```
ado/        commands, help files, Mata, and the Cloud scripts (installed)
examples/   runnable do-files
tests/      run.do, core/, cli/, python/, fixtures/
scripts/    package build, Stata 14 check, cluster test runner
docs/       plan and test reports
```
