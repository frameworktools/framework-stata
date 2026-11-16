---
id: support
title: Support status
description: Native Stata capabilities, backend-assisted drivers, limitations, and test coverage
section: getting_started
position: 3
---

## Native Stata capabilities

These features run directly in Stata and Mata without Python or `fw`:

- Project discovery and directory globals from `settings.yml`, `config.yml`, split YAML files, configuration environments, `env()` references, `.env`, and `settings.do`.
- Session initialization with `fw_scaffold` (project `ado/plus` isolation, missing package installation, random seed, graph scheme, function `ado` path, and `scaffold.do`) and package management with `fw_packages` (SSC, GitHub, and `net` sources).
- Cataloged and dot-named datasets in `.dta`, `.csv`, `.tsv`, `.xlsx`, and `.xls`.
- SHA-256 and `datasignature` integrity verification, dataset locking, and live Framework Cloud ledger updates.
- Table and figure export (`fw_table` and `fw_graph`) with automatic output checksum tracking and sensitive-project directory routing.
- Folder bundle publishing (`framework.bundle/v1`) with version history and the offline HTML reader.
- Framework Cloud file, bundle, and model publishing via `curl`.
- Structured estimation artifacts for `regress`, `logit`, `logistic`, `probit`, `poisson`, `nbreg`, `glm`, `mixed`, `stcox`, and `ivregress`, plus generic coefficient tables for other `e(b)`/`e(V)` estimators.
- Browser-based device login to Framework Cloud with system keyring storage.

## Backend-assisted capabilities

- GitHub Pages publishing
- S3-compatible object storage publishing

Both drivers require either `fw` or `framework-py`. See [Backends](guide:backends).

## Current limitations

- **Separate local integrity stores.** Stata writes checksums to `.framework/stata-integrity.tsv` and `.framework/stata-results.tsv`. R and Python write to SQLite (`framework.db`), which Stata does not read.
- **YAML subset.** Anchors, aliases, merge keys, nested flow collections, and tab indentation stop with an error.
- **R expressions.** Settings beginning with `!expr` evaluate to empty strings in Stata.
- **Tabular file formats.** Native dataset commands read and write `.dta`, `.csv`, `.tsv`, `.xlsx`, and `.xls` only.
- **Project token provisioning.** `fw_login` authenticates the workstation; Cloud publishing still reads `FW_PROJECT_TOKEN` from `.env`.
- **Other estimators.** Commands outside the nine dedicated model mappers publish generic coefficient tables.

## Test coverage notes

The automated suite passes on Linux with Stata 17 from both a repository checkout and `net install`. Areas pending live hardware or service runs:

- Native Windows PowerShell helpers and macOS/Windows keyring integration under live desktop sessions.
- Runtime execution on Stata 14, 15, and 16 (`scripts/check_version14.py` enforces Stata 14 syntax statically).
- End-to-end GitHub Pages and S3 uploads against live remote buckets and repositories.
- Automated suite runs against production `framework.pub` (tests run against a local mock HTTP server).
