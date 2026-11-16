---
id: projects
title: Projects and settings
description: Project discovery, session setup, folder globals, YAML settings, and environments
section: features
position: 1
---

## Project root

[fw_project](ref:fw_project) searches upward from the current working directory up to 10 parent levels. It stops at the first directory containing any of these markers:

- `.framework/`
- `settings.yml`
- `config.yml`
- `settings.do`

```stata
cd "~/projects/example-study/do"
fw_project
```

Pass `root()` to start discovery from an explicit path:

```stata
fw_project, root("~/projects/example-study")
```

Other Framework commands call `fw_project` automatically when no project is loaded. Run `fw_project` or `fw_scaffold` again after switching projects in the same Stata session.

## Session setup

[fw_scaffold](ref:fw_scaffold) runs `fw_project` and applies session settings from `settings.yml`. Place it at the top of `master.do`:

```stata
fw_scaffold
```

In order, `fw_scaffold`:

1. Loads project settings and sets directory globals via `fw_project`.
2. Points Stata's `PLUS` directory to `ado/plus` inside the project when `packages.project_ado` is `true`.
3. Installs missing project packages via [fw_packages](ref:fw_packages) unless `noinstall` is specified.
4. Sets the random number seed when `scaffold.seed_on_scaffold` is `true`, or when `FW_SEED` is set and `seed_on_scaffold` is not `false`.
5. Sets the graph scheme when `scaffold.set_theme_on_scaffold` is `true`.
6. Adds `directories.functions` (or `functions/`) to the ado-path unless `scaffold.source_all_functions` is `false`.
7. Runs `scaffold.do` in the project root when present.

## Folder globals

`fw_project` defines one global macro for each entry in the `directories` mapping.

| Global | Value |
|---|---|
| `$fw_root` | Project root path |
| `$fw_inputs_raw` | Path for `directories.inputs_raw` (and matching `$fw_<key>` globals for every configured directory) |
| `$fw_data` | `directories.data`, else `inputs_final`, else `inputs_public_final` when configured |
| `$fw_outputs` | `outputs` directory when present |
| `$fw_project_name` | `project_name`, else `project.name`, else `name`, else the root folder name |

Paths are absolute and use forward slashes on all operating systems. Loading a project clears `$fw_*` globals from any previous project. Directory keys whose macro name would exceed Stata's 32-character limit are skipped with a notice.

```stata
fw_project
use "$fw_inputs_raw/survey.dta", clear
graph export "$fw_outputs_figures/price.png", replace
```

## settings.yml

Stata reads the same `settings.yml` file used by R, Python, and `fw`.

```yaml
default:
  project_name: example-study
  directories:
    inputs_raw: inputs/raw
    inputs_final: inputs/final
    outputs_figures: outputs/figures
  data: settings/data.yml
```

String values ending in `.yml` (such as `data: settings/data.yml`) load and merge that split YAML file. `config.yml` follows the same rules.

### Supported YAML syntax

Stata includes a native Mata YAML parser supporting the constructs used in Framework configuration files:

- Block mappings, sequences, and scalars
- Comments (`#`)
- Single-quoted and double-quoted strings
- Single-level flow sequences and mappings, such as `tags: [alpha, beta]`
- Literal (`|`) and folded (`>`) block scalars

Anchors, aliases, merge keys, nested flow collections, and tab indentation raise an error.

### Environment variables in YAML

Values written as `env("NAME", "default")` resolve from the process environment first, then the project's `.env` file, and finally the fallback string. Values starting with `!expr` contain R expressions and evaluate to empty strings in Stata.

```yaml
default:
  directories:
    inputs_raw: env("SURVEY_DIR", "inputs/raw")
```

## Configuration environments

Top-level YAML keys other than `default` define named environments whose keys override `default`. Stata selects the active environment from the first set variable:

1. `FW_CONFIG_ACTIVE`
2. `R_CONFIG_ACTIVE`
3. `R_CONFIG_NAME`
4. `default`

```yaml
default:
  directories:
    inputs_raw: inputs/raw
staging:
  directories:
    inputs_raw: inputs/raw-staging
```

Export the variable before starting Stata, such as `FW_CONFIG_ACTIVE=staging stata`.

## settings.do

Stata projects scaffolded with `fw new --lang stata` also include `settings.do`:

```stata
global root `"`c(pwd)'"'
global inputs_raw `"$root/inputs/raw"'
global outputs_figures `"$root/outputs/figures"'
```

`fw_project` parses `global` assignments whose path begins with `$root/`, `${root}/`, or an absolute path, setting `$fw_inputs_raw` and matching `$fw_*` globals. Lines built from other macros are ignored, and user globals such as `$inputs_raw` remain unchanged.

## Combined settings.yml and settings.do

Projects can keep both files:

| File | Contents | Readers |
|---|---|---|
| `settings.do` | Directory globals such as `$inputs_raw` | Plain Stata scripts and `fw_project` |
| `settings.yml` | `project_name`, `directories`, `packages`, `scaffold`, `data`, `publish`, `security`, and `options` | `fw_project`, all Framework Stata commands, R, Python, and `fw` |

`fw_project` loads `settings.yml` first and appends any `settings.do` directories absent from `settings.yml`. All Framework commands operate on that merged configuration. When both files define different paths for the same directory key, `settings.yml` wins, `fw_project` prints a notice, and `r(conflicts)` lists the conflicting keys.

## Numeric precision

Stata creates new numeric variables as `float` unless configured otherwise. Commands such as `generate` and `collapse (mean)` on non-`double` variables retain roughly seven significant digits, whereas R and Python use double precision (`~1e-16`), producing differences around `1e-7`.

Set `double` as the session default near the top of `master.do` when matching R or Python outputs:

```stata
version 14
set type double
fw_scaffold
```

`set type double` lasts for the active Stata session. Existing `float` variables keep their storage type until converted with `recast double`. `fw_use` imports decimal values from CSV and TSV files as `double` by default.

## Stored results

`fw_project` stores `r(root)`, `r(name)`, `r(folders)` (space-separated directory keys), and `r(conflicts)` (directory keys where `settings.yml` and `settings.do` differed).
