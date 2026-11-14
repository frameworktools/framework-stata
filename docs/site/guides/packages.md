---
id: packages
title: Packages
description: The packages a project lists, and installing them from SSC, GitHub, or a web address
section: features
position: 7
---

## Package list

A project lists the community packages its do-files use. [fw_packages](ref:fw_packages) reads the list and installs what is missing, as `packages_install()` does in R and Python.

List the packages under `packages` in `settings.yml`, or in `settings/packages.yml`, the file R writes:

```yaml
packages:
  project_ado: true
  default_packages:
    - name: estout
      source: ssc
    - name: reghdfe
      source: github
      repo: sergiocorreia/reghdfe
      ref: 6.12.3
    - name: mytools
      source: net
      url: https://example.org/stata
```

| Source | Installs with | Fields |
|--------|---------------|--------|
| `ssc` | `ssc install` | `name`. The default source. |
| `github` | `net install` from the repository | `repo`, and `ref` for a tag, branch, or commit. Without `ref`, the default branch. |
| `net` | `net install` from a folder or web address | `url`, the place that holds *name*`.pkg` |

A plain entry is shorthand. `- estout` is an SSC package, and `- sergiocorreia/reghdfe@6.12.3` is a GitHub package at tag 6.12.3. Entries for R and Python, with source `cran`, `bioc`, or `pypi`, are listed as skipped.

## Installing

```stata
fw_packages              // what is installed and what is missing
fw_packages install      // install the missing packages
fw_packages update       // reinstall every package
fw_packages update reghdfe
```

A package that fails to install does not stop the others. `fw_packages` then stops with the first error and names the packages that failed.

## Project packages

SSC keeps no old versions. A GitHub `ref` fixes a version, but most packages come from SSC. To keep exact versions, set `project_ado: true`. Packages then install into `ado/plus` in the project folder. Commit that folder, and everyone who runs the project uses the same code without installing anything.

Without `project_ado`, packages install into Stata's PLUS folder, `c(sysdir_plus)`, which every project on the computer shares.

`fw_packages` points PLUS at the project folder only while it installs. [fw_scaffold](ref:fw_scaffold) points it there for the whole session and installs any missing packages, so `master.do` needs one line:

```stata
fw_scaffold
```
