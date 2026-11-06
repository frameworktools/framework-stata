---
id: projects
title: Projects and settings
description: Finding the project, folder globals, settings files, and environments
section: features
position: 1
---

## Project root

[fw_project](ref:fw_project) walks up from the current folder, at most 10 levels. It stops at the first folder with one of these:

- a `.framework/` folder
- `settings.yml`
- `config.yml`
- `settings.do`

```stata
cd "~/projects/example-study/notebooks"
fw_project
```

Start the search somewhere else with `root()`.

```stata
fw_project, root("~/projects/example-study")
```

Other commands run `fw_project` themselves when no project is loaded. Run it again after you change to another project.

## Folder globals

`fw_project` sets one global for each folder in the `directories` section of the settings.

| Global | Value |
|--------|-------|
| `$fw_root` | The project folder |
| `$fw_inputs_raw` | `directories: inputs_raw`, and so on for every key |
| `$fw_data` | The `inputs_final` folder, when the settings have one |
| `$fw_outputs` | The `outputs` folder, when it exists |
| `$fw_project_name` | `project.name`, else the folder name |

Paths are absolute and use forward slashes on every system. Globals from a previous project are cleared. A key whose global name would pass Stata's 32-character limit is skipped, and the summary says so.

```stata
fw_project
use "$fw_inputs_raw/survey.dta", clear
graph export "$fw_outputs_figures/price.png", replace
```

## settings.yml

Stata reads the same `settings.yml` as R, Python, and `fw`.

```yaml
default:
  project:
    name: example-study
  directories:
    inputs_raw: inputs/raw
    inputs_final: inputs/final
    outputs_figures: outputs/figures
  data: settings/data.yml
```

A value that names a `.yml` file, such as `data: settings/data.yml`, is read from that file. `config.yml` works the same way.

### Supported YAML

Stata has its own YAML reader. It supports the YAML features that Framework settings use:

- mappings, lists, and scalars
- comments
- quoted strings
- flow lists and maps one level deep, such as `tags: [alpha, beta]`
- literal (`|`) and folded (`>`) blocks

Anchors, aliases, merge keys, and nested flow collections stop with an error. So does a tab in the indentation: YAML allows only spaces there.

### Values from the environment

A value written as `env("NAME", "default")` reads the environment variable, then the project's `.env` file, then the default. Values that start with `!expr` are R code and read as empty in Stata.

```yaml
default:
  directories:
    inputs_raw: env("SURVEY_DIR", "inputs/raw")
```

## Environments

Top-level sections other than `default` are environments. The active environment's values replace the defaults. Stata picks the environment from these variables, in order:

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

Set the variable before Stata starts, for example `FW_CONFIG_ACTIVE=staging stata`.

## settings.do

Projects that `fw new --lang stata` creates keep their folders in `settings.do`:

```stata
global root `"`c(pwd)'"'
global inputs_raw `"$root/inputs/raw"'
global outputs_figures `"$root/outputs/figures"'
```

`fw_project` reads each `global` line whose path starts with `$root/` or `${root}/`, or is an absolute path, and sets `$fw_inputs_raw` and the rest. It skips other lines, such as paths built from other globals. It leaves the project's own globals, such as `$inputs_raw`, untouched.

## Stored results

`fw_project` stores `r(root)`, `r(name)`, and `r(folders)`, the list of folder keys.
