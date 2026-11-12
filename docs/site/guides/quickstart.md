---
id: quickstart
title: Quick start
description: A project, a named dataset, a model, and a published result
section: getting_started
position: 2
---

## Project

Start Stata in the project folder, or `cd` into it. [fw_project](ref:fw_project) finds the project and sets a global for each folder.

```stata
cd "~/projects/example-study"
fw_project
```

Projects come from `fw new`, from R or Python, or from Framework Cloud. A folder with a `settings.yml` file is enough. See [Projects and settings](guide:projects).

In a terminal, `fw new example-study --lang stata` asks where to create the project. It offers a folder named for the project in the current directory. Answer `n` to give another folder, or pass `--dir` to name it. Without a terminal, `fw new` needs `--dir`.

This settings file names the folders and a local folder destination, so every step below works offline:

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

[fw_save](ref:fw_save) saves the data in memory under a name and records its checksum. [fw_use](ref:fw_use) loads it and checks that it has not changed.

```stata
sysuse auto, clear
fw_save inputs.raw.cars, replace
fw_use inputs.raw.cars, clear
```

`inputs.raw.cars` is `$fw_inputs_raw/cars.dta`. See [Data and integrity](guide:data).

## Model

```stata
regress price mpg weight
fw_publish, estimates title("Price model")
```

[fw_publish](ref:fw_publish) turns the estimation results into a model that Framework Cloud and the offline reader display. Here it goes to the `local` folder destination: open `published/index.html` to see it. See [Estimation results](guide:estimates).

## Figure

`graph export` does not create folders. Projects from `fw new` have them. Otherwise, create them first:

```stata
capture mkdir "$fw_root/outputs"
capture mkdir "$fw_outputs_figures"
scatter price mpg
graph export "$fw_outputs_figures/price.png", replace
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
```

Without `to()`, results go to the project's default destination. A project with no default goes to Framework Cloud, which needs a project token. See [Publishing](guide:publishing).

## Examples

The `examples` folder of the repository has five runnable do-files. They use `sysuse auto` and a temporary project, and publish to a local folder. `05-cleanup.do` removes the project.
