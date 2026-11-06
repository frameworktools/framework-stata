---
id: support
title: Support status
description: Stata features, backend features, and untested areas
section: getting_started
position: 3
---

## Native support

These run in Stata and Mata, with no Python:

- Project discovery and folder globals from `settings.yml`, `config.yml`, split files, environments, `env()` values, `.env`, and `settings.do`.
- Named datasets in `.dta`, `.csv`, `.tsv`, `.xlsx`, and `.xls`, by path, catalog name, or dot name.
- Integrity checks with SHA-256 and `datasignature`, locked datasets, and the integrity ledger.
- Publishing files to a folder, with the shared bundle format, versions, and an offline reader.
- Publishing files and models to Framework Cloud with curl.
- Models from `regress`, `logit`, `logistic`, `probit`, `poisson`, `nbreg`, `glm`, `mixed`, `stcox`, and `ivregress`, and a generic table for other commands.
- Browser login to Framework Cloud, with the token in the system keyring.

## Backend support

- Publishing to GitHub Pages
- Publishing to S3

Both need `fw` or framework-py. See [Backends](guide:backends).

## Unsupported features

- **Shared integrity records.** Stata keeps its records in `.framework/stata-integrity.tsv`. R and Python keep theirs in `framework.db`, which Stata cannot read. Each language checks its own records.
- **Full YAML.** Anchors, aliases, merge keys, and nested flow collections stop with an error.
- **`!expr` settings.** These are R code and read as empty.
- **Other data formats.** Stata reads and writes `.dta`, `.csv`, `.tsv`, `.xlsx`, and `.xls` only.
- **Project login.** `fw_login` connects the computer. Cloud publishing still needs the project token in `.env`.
- **Model mappings for other commands.** They get the generic coefficient table.

## Untested areas

The test suite passes on Linux with Stata 17, both from a checkout and after `net install`. These have not been run yet:

- Windows and macOS, including the PowerShell scripts and the keyring on each system
- Stata 14, 15, and 16. A static check keeps the core within Stata 14 syntax.
- Publishing to GitHub Pages and S3 through either backend
- Publishing and login against a live Framework Cloud server. The tests use a local mock server.
