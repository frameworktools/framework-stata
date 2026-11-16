---
id: quickstart
title: Quick start
description: Project initialization, cataloged datasets, model publishing, and figures
section: getting_started
position: 2
---

## Project setup

Start Stata in a project directory or `cd` into one. [fw_scaffold](ref:fw_scaffold) loads the project, sets directory globals, configures project packages, and applies session settings. Use [fw_project](ref:fw_project) when you want path globals without running session setup.

```stata
cd "~/projects/example-study"
fw_scaffold
```

Create Stata projects from Framework Cloud or with `fw new` in a terminal. Any directory containing `settings.yml` also works as a project root. See [Projects and settings](guide:projects).

In an interactive terminal, `fw new example-study --lang stata` prompts for the target directory and defaults to `./example-study`. Enter `n` to choose another path, or pass `--dir` directly. Non-interactive runs require `--dir`.

The `settings.yml` below configures input and figure directories alongside a local folder publishing destination so every step runs offline:

```yaml
default:
  directories:
    inputs_raw: inputs/raw
    outputs_figures: outputs/figures
  publish:
    default: local
    destinations:
      local:
        driver: folder
        path: published
        visibility: private
```

## Named datasets

[fw_save](ref:fw_save) writes the dataset in memory under a catalog or dot name and records its checksum. [fw_use](ref:fw_use) loads the dataset and verifies that the file matches its recorded checksum.

```stata
sysuse auto, clear
fw_save inputs.raw.cars, replace
fw_use inputs.raw.cars, clear
```

`inputs.raw.cars` resolves to `$fw_inputs_raw/cars.dta`. See [Data and integrity](guide:data).

## Estimation results

```stata
regress price mpg weight
fw_publish, estimates title("Price model")
```

[fw_publish](ref:fw_publish) serializes the active estimation results into a model artifact rendered by Framework Cloud and the offline reader. With the `local` destination above, open `published/index.html` to view the published model. See [Estimation results](guide:estimates).

## Figures

[fw_graph](ref:fw_graph) exports the current graph to the project's figures directory, creates missing subdirectories, and records the output checksum. You can also export directly with `graph export` when the directory exists:

```stata
scatter price mpg
fw_graph price
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
```

When `to()` is omitted, `fw_publish` uses `publish.default` from `settings.yml`. Projects without a default destination publish to Framework Cloud using `FW_PROJECT_TOKEN` in `.env`. See [Publishing](guide:publishing).

## Examples

The repository's `examples` directory contains five runnable do-files using `sysuse auto` and a temporary local project. `05-cleanup.do` removes the temporary files.
