---
id: packages
title: Packages
description: Project package lists and installation from SSC, GitHub, or net URLs
section: features
position: 8
---

## Package configuration

Projects declare community Stata packages under `packages` in `settings.yml` or `settings/packages.yml`. [fw_packages](ref:fw_packages) checks installed status and installs missing packages, matching `packages_install()` in R and Python.

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

| Source | Installer | Fields |
|---|---|---|
| `ssc` | `ssc install` | `name` (default source when omitted) |
| `github` | `net install` from GitHub | `repo`, plus optional `ref` (tag, branch, or commit; defaults to the repository default branch) |
| `net` | `net install` from a directory or URL | `url` pointing to the location of `<name>.pkg` |

Plain strings use shorthand notation: `- estout` installs `estout` from SSC, and `- sergiocorreia/reghdfe@6.12.3` installs `reghdfe` from GitHub at ref `6.12.3`. Entries with `cran`, `bioc`, or `pypi` sources belong to R or Python and are reported as skipped.

## Package installation

```stata
fw_packages              // list installed and missing packages
fw_packages install      // install missing packages
fw_packages update       // reinstall all configured packages
fw_packages update reghdfe
```

If a package fails to install, `fw_packages` attempts the remaining packages first, then exits with the first error code and lists all failed package names.

## Project ado directory

SSC does not archive historical package versions. Setting `project_ado: true` installs packages into `ado/plus` inside the project directory instead of Stata's shared `c(sysdir_plus)` directory. Committing `ado/plus` to Git pins exact `.ado` and `.mata` files for every collaborator without separate installation steps.

`fw_packages` switches `PLUS` to `ado/plus` only during package operations. [fw_scaffold](ref:fw_scaffold) configures `PLUS` for the entire Stata session and installs any missing packages automatically:

```stata
fw_scaffold
```
