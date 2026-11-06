# JHPCE test report

Date: 2026-11-05. Cluster: JHPCE. Stata ran only on compute nodes, through
Slurm (`srun --mem=4G`), never on the login node.

## Environment

| Item | Value |
|---|---|
| Stata | 17.0 BE, Unix, batch mode (`module load stata/17`) |
| fw | `0.0.0-stata-dev`, cross-compiled from the local framework-cli checkout, in `~/bin` |
| Python | CPython 3.11.18 from `uv python install 3.11` (shared libpython) |
| framework-py | `0.1.0.dev6` from the local checkout, in a venv added with `python set userpath` |
| Cloud | a local mock server (`tests/fixtures/mock_cloud.py`) on the compute node |
| Config folder | a fresh `mktemp -d` per run (`FW_CONFIG_HOME`), so no real token files were touched |

Run it again with `scripts/jhpce-test.sh`. Set `FW_TEST_NETINSTALL=1` in its
argument to test the `net install` copy. These results come from a copy of
that script that also counts `St*` entries in the node's /tmp before and
after the run.

## Results

| Run | Node | Passed | Failed | Skipped |
|---|---|---|---|---|
| Source tree (`adopath ++ ado`) | compute node | 84 | 0 | 0 |
| `net install framework, from(<checkout>)` into a temporary PLUS folder | compute-120 | 84 | 0 | 0 |

These runs added `fw_use, check(accept)` and its five tests. They ran with
`FW_JHPCE_DIR=fw-dev/accept-2026-11-05`, the mock Cloud server, and a fresh
`FW_CONFIG_HOME`. Both reached `ALL TESTS PASSED`. The fake user and project
tokens appeared 0 times in either `run.log`. The logs stay in
`~/fw-dev/accept-2026-11-05/logs/`. The earlier run of 79 tests also found no
new `St*` entries in the node's /tmp.

### Summary from run.log

```
Framework for Stata tests on Stata 17 (Unix)
  passed:  84
  skipped: 0
  failed:  0
ALL TESTS PASSED
```

### net install excerpt

```
. net install framework, from(`"`repo'"') replace
installing into /tmp/St2614947.000001_plus/...
installation complete.
. which fw_publish
/tmp/St2614947.000001_plus/f/fw_publish.ado
```

### Every test

```
PASS settings: find the root from a nested folder
PASS settings: directory globals are absolute
PASS settings: split file and nested data catalog
PASS settings: flow lists, block scalars, lists of maps
PASS settings: the active environment overrides default
PASS settings: fw-generated settings.do supplies folders
PASS settings: no project gives a clear error
PASS json: parse nested values, escapes, and numbers
PASS json: numbers and strings round-trip
PASS paths: the private-path rule
PASS paths: slugs match R and Python
PASS paths: helpers leave their arguments unchanged
PASS settings: tab indentation stops with a clear error
PASS settings: settings.do lines with braces and absolute paths
PASS settings: a key too long for a global is reported, not listed
PASS data: fw_save writes a dot-named .dta and records it
PASS data: SHA-256 matches the operating system tool
PASS data: fw_use loads and verifies
PASS data: fw_save refuses to overwrite without replace
PASS data: a changed locked file stops fw_use with error 459
PASS data: check(warn) loads a changed file with a warning
PASS data: unlocked datasets warn and update the record
PASS data: cataloged CSV from the settings catalog
PASS data: CSV and Excel round trips by path
PASS data: unknown folders give a clear error
PASS data: relative paths fall back to the project root from a subfolder
PASS data: the 459 message gives the way to accept a change
PASS data: check(accept) records a changed locked .dta without rewriting it
PASS data: check(accept) records a changed locked CSV without rewriting it
PASS data: check(accept) on an unchanged dataset leaves the record alone
PASS data: check(accept) on a plain file path gives a clear error
PASS estimates: regress matches its own table
PASS estimates: logit and logistic give odds ratios on the log scale
PASS estimates: probit, poisson, nbreg
PASS estimates: glm families and links
PASS estimates: mixed with random intercepts and slopes
PASS estimates: stcox gives hazard ratios with no intercept
PASS estimates: ivregress records instruments
PASS estimates: other commands publish a generic coefficient table
PASS estimates: nbreg dispersion(constant) reports delta, not a coefficient
PASS estimates: tobit's variance goes in the ancillary table without a test
PASS estimates: no results gives error 301
PASS publish: a figure goes to the default folder destination
PASS publish: the manifest lists every file with its checksum
PASS publish: a second publish adds version 2 and keeps version 1
PASS publish: estimates become a model with the offline reader
PASS publish: saving() refuses to overwrite without replace
PASS publish: private paths stop batch publishing without the option
PASS publish: folder visibility must match the destination
PASS publish: unknown destinations and missing files give clear errors
PASS publish: GitHub without a backend under fw_set backend core
PASS publish: an HTML report keeps its _files folder
PASS publish: stcox gets its own default name
PASS publish: r(file) after estimates names the saved copy
PASS publish: to(folder) and an unset visibility name the fix
PASS cloud: fw_login completes the browser approval flow
PASS cloud: the device flow sent no token until approval
PASS cloud: fw_setup reports the login without printing the token
PASS cloud: fw_publish uploads to the project with its project token
PASS cloud: fw_save pushes a ledger entry when the ledger is live
PASS cloud: fw_use, check(accept) pushes the new checksum when the ledger is live
PASS cloud: folder publishing records metadata on the linked project
PASS cloud: r(slug) matches the uploaded slug for an HTML report
PASS cloud: a missing project token names the fix
PASS cloud: a live ledger without a project token says it skipped the push
PASS cloud: a refused login request does not mention a token it never sent
PASS cloud: fw_logout removes the token file
PASS examples: 01-project.do runs
PASS examples: 02-data.do runs
PASS examples: 03-publish.do runs
PASS examples: 04-estimates.do runs
PASS examples: the folder site lists every artifact
PASS examples: 05-cleanup.do removes the example project
PASS cli: fw_publish delivers a figure through fw
PASS cli: estimates publish as a model through fw
PASS cli: confirmed private paths pass --include-private
PASS cli: fw errors come back as Stata errors
PASS cli: fw_setup describes the cli backend
PASS cli: a stale fw_path falls back to the PATH and is named
PASS python: an old Python gets version advice, not pip advice
PASS python: _fw_python finds framework-py
PASS python: fw_publish delivers a figure through framework-py
PASS python: estimates publish as a model through framework-py
PASS python: framework-py errors come back as Stata errors
```

## Findings along the way

- **Graphs work in console Stata on a compute node.** `scatter` and
  `graph export` run in batch mode, with graphics on or off.
  `examples/03-publish.do` draws its figure in batch mode too. An earlier
  note here said graphs hang. That did not reproduce on 2026-11-05. The
  example once failed because `graph export` does not create folders; it now
  creates `outputs/figures` first. The tests still use a fixture PNG.
- **JHPCE's Python modules are static.** `python/3.11.8`, `3.12.12`, and
  `3.13.4` ship `libpython*.a` only, and Stata's `python set exec` needs a
  shared library. The system Python is 3.9, too old for framework-py.
  `fw_setup` now says so instead of suggesting `pip install`. A
  `uv`-installed Python works.
- **The `uv` symbolic link works.** `python set exec` with
  `cpython-3.11-linux-x86_64-gnu/bin/python3.11` and with the resolved
  `cpython-3.11.18-…` path both work. An earlier note here said the link
  fails; that did not reproduce. `scripts/jhpce-test.sh` still resolves it.
- **`secret-tool` is installed, but no Secret Service runs.** A lookup fails
  with "The name is not activatable". `fw_setup` and `fw_login` now probe the
  service, so both report a token file.
- **`net install` drops non-Stata file types.** `.sh`, `.ps1`, `.html`,
  `.txt`, `.json`, `.csv`, `.do`, and `.dta` are skipped silently. The Cloud
  scripts and the reader template ship as `.ihlp` files.
- **Stata 17 names `mixed` parameters `lns<level>_1_<component>` and
  `atr<level>_1_<c>_<d>`, and stores `e(redim)` as a macro.** The mapping
  handles both these and the older matrix form.
- **`tobit` names its variance `var(e.y):_cons` under version 15 and newer,
  and `sigma:_cons` under version 14.** The tests run under `version 14`, so
  the tobit test runs both.
- **A background process started with Stata's `shell … &` does not survive.**
  The test script starts the mock server before Stata.

## Not tested

- Windows and macOS. The PowerShell script, `winexec` with a hidden
  `wscript` runner, Windows Credential Manager, and the macOS Keychain are
  written but have not run.
- Stata 14, 15, and 16. `scripts/check_version14.py` checks core files for
  newer commands; Stata 17 under `version 14` does not prove older releases work.
- A live Framework Cloud publish. Compute nodes ran against the mock server.
  The throwaway test instance on framework-selfhost is the next step, with a
  token supplied through a secret prompt.
- GitHub Pages and S3 through the backends. The CLI and Python layers were
  tested with folder destinations.
