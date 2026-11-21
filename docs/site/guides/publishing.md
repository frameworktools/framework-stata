---
id: publishing
title: Publishing
description: Destinations, folder bundles, Framework Cloud uploads, and private-path checks
section: features
position: 3
---

## File publishing

[fw_publish](ref:fw_publish) publishes a single file or directory as a versioned artifact: figures, tables, rendered HTML documents, or arbitrary data and archive files. Each publish appends a new version while preserving prior versions.

```stata
graph export "$fw_outputs_figures/price.png", replace
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
```

Artifact kind is inferred from the file extension: `.png`, `.jpg`, `.svg`, `.gif`, and `.webp` map to `image`; `.html` maps to `html` and bundles any companion `<name>_files` directory; other extensions map to `file`. Override detection with `kind()`.

| Option | Effect |
|---|---|
| `slug()` | URL identifier for the artifact (defaults to the file stem) |
| `title()` | Display title shown to readers |
| `description()` | Short summary |
| `to()` | Destination name or driver |
| `visibility()` | `public`, `unlisted`, or `private` |
| `private` | Shorthand for `visibility(private)` |
| `includeprivate` | Confirms publishing from paths containing `private` |
| `kind()` | Explicit artifact kind override |

For model publishing with `fw_publish, estimates`, see [Estimation results](guide:estimates). For commands and their printed output, see [Code snippets](guide:snippets).

## Directory and wildcard bundles

Passing a directory path publishes every file inside that directory and its subdirectories as a single artifact, matching `publish_dir()` in R and Python. Passing a wildcard pattern such as `"$fw_outputs_figures/*.png"` bundles matching files in that directory without recursing into subdirectories.

```stata
fw_publish "$fw_outputs_figures/meeting", title("Meeting figures")
fw_publish "$fw_outputs_figures/*.png", slug(all-figures)
```

Relative paths within the directory are preserved, `slug()` and `title()` default to the directory name, and the artifact kind defaults to `html`. If the directory has no `index.html`, Stata generates a directory listing page matching `framework-py`. On Framework Cloud, multi-file bundles open at `index.html` or the first top-level HTML page. Every bundled file is checked against the [private-path rule](#private-paths), and `r(files)` reports the file count.

## Destinations

When `to()` is omitted, `fw_publish` uses `publish.default` from `settings.yml`, falling back to Framework Cloud. Named destinations live under `publish.destinations`:

```yaml
default:
  publish:
    default: lab
    destinations:
      lab:
        driver: folder
        path: /Volumes/lab/published
        visibility: private
```

```stata
fw_publish "$fw_outputs_figures/price.png", to(lab)
```

`to()` accepts a configured destination name or a driver name (`cloud`, `folder`, `github`, or `s3`). Because folder destinations require a target path, bare `to(folder)` stops with an error; define a named destination in `settings.yml` instead.

| Driver | Handler |
|---|---|
| `folder` | Stata |
| `cloud` | Stata (`curl`) |
| `github` | `fw` or `framework-py` |
| `s3` | `fw` or `framework-py` |

GitHub Pages and S3 require a configured backend. See [Backends](guide:backends).

## Folder destinations

Folder destinations write the standard `framework.bundle/v1` structure to local disks or mounted network shares:

- Artifact files with SHA-256 checksums
- `artifact.json` and `representation.json`
- `index.html`, a self-contained offline reader
- Versioned subdirectories (`v/1`, `v/2`, and subsequent versions)

Top-level `index.html` and `index.json` files catalog every published artifact in the destination directory. If the destination specifies `visibility`, `visibility()` must match it; destinations without `visibility` reject per-call `visibility()` overrides.

When `.env` includes `FW_PROJECT_TOKEN`, folder publishes also register artifact metadata and checksums with Framework Cloud while leaving all files on the local or mounted folder.

## Framework Cloud

Cloud uploads transfer files over HTTPS via `curl`, authenticating with `FW_PROJECT_TOKEN` in the project's `.env` file:

```sh
FW_PROJECT_TOKEN=paste-the-project-token-here
```

Issue project tokens from the project's **Computers & tokens** page in Framework Cloud, and keep `.env` excluded from Git. Stata resolves the server URL from `FW_CLOUD_URL` in `.env`, then the process environment, then the saved login server. When `.env` has `FW_PROJECT_TOKEN` but no `FW_CLOUD_URL`, publishing stops instead of using the saved login. Add `FW_CLOUD_URL` to `.env`. With no server set, publishing stops rather than use `https://framework.pub`.

HTML files with a companion `<name>_files` directory upload as a single ZIP bundle.

After a Cloud publish, `fw_publish`, `fw_dag`, and `fw_snippet end` print the version and two links:

```text
Published version 3.
Share:  https://framework.pub/go/az7h
Manage: https://framework.pub/artifacts/123
```

Share is the link to paste into a blog or site that takes Framework embeds: a public artifact's short link, or an unlisted artifact's own link. Private and password-protected artifacts have none. Manage is the owner's page for the artifact on Framework Cloud. `r(embed_link)` and `r(artifact_url)` hold them. An older server, or fw before 0.8.6, reports neither, and the first line names the published link instead.

New Cloud artifacts default to `unlisted` visibility (accessible to anyone with the link and omitted from public indexes). Subsequent publishes without `visibility()` preserve the artifact's existing visibility. Setting `slug()` assigns the readable identifier without altering visibility.

## Display settings

`display()` sets what embeds of an artifact show on other sites, such as blog posts. It takes `key=on` or `key=off`, separated by spaces:

```stata
fw_dag "age -> smoking -> cancer" "age -> cancer", exposure(smoking) outcome(cancer) display(analysis=on dagitty=on)
fw_publish, estimates display(details=off)
```

| Key | Applies to | Off means |
|---|---|---|
| `title`, `description`, `author` | all | The embed leaves it out. |
| `credit` | all | No link back to the artifact on Framework Cloud. |
| `details` | models and tests | No details section. |
| `variable_tips` | models | No tips on terms. |
| `column_summaries` | tables | No column summaries in tips. |
| `output` | code snippets | The output starts hidden. |
| `links` | code snippets | No notebook and model links. |
| `legend`, `analysis`, `dagitty`, `code` | DAGs | No role legend, analysis, DAGitty code, or source code. |
| `interactive` | Vega-Lite charts | The static image shows instead. |

Settings are on by default, except that a DAG embeds as its drawing alone: its `description`, `analysis`, `dagitty`, and `code` start off. Framework Cloud keeps an artifact's settings across versions. A publish changes only the keys it names, and a publish without `display()` changes nothing. The reader page always shows everything. An unknown key or a value other than `on` or `off` stops with error 198 before anything is published.

`fw_publish`, `fw_dag`, and `fw_snippet end` take `display()`. The core backend and framework-py send it to Framework Cloud. The `fw` backend needs fw 0.8.3 or newer. Folder destinations ignore it.

## Private paths

Any file whose full path contains `private` (case-insensitive) requires explicit confirmation before publishing. Interactive Stata prompts for confirmation. Batch mode stops with error 198 unless `includeprivate` is passed. Note that `private` sets `visibility(private)` and does not bypass the path check.

```stata
fw_publish "$fw_outputs_private/table.csv", to(lab) includeprivate
```

R, Python, and `fw` enforce the same check. Framework never uploads files without an explicit publish call.

## Stored results

| Macro / scalar | Description |
|---|---|
| `r(url)` | Published reader URL when supported by the destination |
| `r(location)` | Output directory path for `folder` destinations |
| `r(version)` | Published version number |
| `r(version_url)` | Version-specific URL |
| `r(embed_link)` | Share link, to paste into a site that takes Framework embeds, when Cloud gives one |
| `r(artifact_url)` | Manage link, the owner's page for the artifact on Cloud |
| `r(unchanged)` | `1` when Cloud kept the latest version of an unchanged code snippet |
| `r(destination)` | Destination name |
| `r(driver)` | `cloud`, `folder`, `github`, or `s3` |
| `r(backend)` | `core`, `cli`, or `python` |
| `r(slug)` | Stored artifact slug (trailing `.html` is stripped on Cloud) |
| `r(file)` | Published path, or the `saving()` path for `estimates` |
| `r(files)` | Number of files published |

All backends populate this return set. Fields unsupported by a given driver or backend (such as `r(location)` on Cloud, or `r(version)` via `framework-py` on Cloud, GitHub Pages, and S3) return empty.
