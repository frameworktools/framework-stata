---
id: publishing
title: Publishing
description: Destinations, folder bundles, Framework Cloud, and private paths
section: features
position: 3
---

## Files

[fw_publish](ref:fw_publish) publishes one file at a time: a figure, a table, a rendered HTML document, or any other file. Each publish adds a version and keeps the earlier ones.

```stata
graph export "$fw_outputs_figures/price.png", replace
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")
```

The kind comes from the extension. Images (`.png`, `.jpg`, `.svg`, `.gif`, `.webp`) are `image`. HTML is `html`, and its `name_files` folder goes with it. Anything else is `file`. Set it with `kind()`.

| Option | Meaning |
|--------|---------|
| `slug()` | The artifact's name in its link. The default comes from the file name. |
| `title()` | The title readers see |
| `description()` | A short description |
| `to()` | The destination |
| `visibility()` | `public`, `unlisted`, or `private` |
| `private` | Short for `visibility(private)` |
| `includeprivate` | Confirms files with "private" in their path |
| `kind()` | Overrides the detected kind |

For estimation results, see [Estimation results](guide:estimates).

## Destinations

Without `to()`, `fw_publish` uses `publish.default` from the settings, then Framework Cloud. Named destinations live in the settings, as in R and Python.

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

`to()` takes a destination name, or a driver: `cloud`, `folder`, `github`, or `s3`. A folder needs a path, so `to(folder)` alone stops with an error. Name a folder destination in the settings and use its name.

| Driver | Handled by |
|--------|------------|
| `folder` | Stata |
| `cloud` | Stata, with curl |
| `github` | `fw` or framework-py |
| `s3` | `fw` or framework-py |

GitHub Pages and S3 need a backend. See [Backends](guide:backends).

## Folder destinations

A folder destination needs a `path`. It can be a shared drive or any folder. `fw_publish` writes the same `framework.bundle/v1` bundle that R and Python write:

- the file, with its SHA-256 checksum
- `artifact.json` and `representation.json`
- `index.html`, an offline reader that opens without a server
- `v/1`, `v/2`, and so on, one folder per version

The folder's own `index.html` and `index.json` list every artifact in it. `visibility()` must match the destination's `visibility`. A destination without a `visibility` setting takes no `visibility()`.

When the project has a Cloud project token, a folder publish also registers the artifact with Framework Cloud. Only the metadata and checksums are sent. The file stays in the folder.

## Framework Cloud

Publishing to Cloud uploads the file with curl. It uses the project token from `FW_PROJECT_TOKEN` in the project's `.env` file.

```sh
FW_PROJECT_TOKEN=paste-the-project-token-here
```

The token comes from the project's page in Framework Cloud. Keep `.env` out of git. The server is `FW_CLOUD_URL` in `.env` or the environment, else `https://framework.pub`.

An HTML file and its `name_files` folder upload as one zip file.

`visibility()` sets who can open the artifact. Without it, a new artifact is unlisted: anyone with the link can open it, but it is not listed. A later publish without `visibility()` keeps the current visibility. `slug()` names the artifact; it does not change the visibility.

## Private paths

A file whose full path contains "private", in any case, needs confirmation. Interactive Stata asks. Batch mode stops with error 198 until you add the `includeprivate` option. The `private` option sets visibility, not this confirmation.

```stata
fw_publish "$fw_outputs_private/table.csv", to(lab) includeprivate
```

R, Python, and `fw` follow the same rule. Nothing is uploaded without an explicit `fw_publish`.

## Stored results

| Result | Value |
|--------|-------|
| `r(url)` | The published link, when the destination has one |
| `r(location)` | The published folder, for folder destinations |
| `r(version)` | The version number |
| `r(version_url)` | The link to this version |
| `r(destination)` | The destination name |
| `r(driver)` | `cloud`, `folder`, `github`, or `s3` |
| `r(backend)` | `core`, `cli`, or `python` |
| `r(slug)` | The artifact name |
| `r(file)` | The file that was published. With `estimates`, the `saving()` copy, else empty |

Every backend sets these results. `r(version)`, `r(version_url)`, and `r(location)` are empty when the destination does not report them: Cloud has no folder, and framework-py does not report a version for Cloud, GitHub, or S3. `r(slug)` is the name the destination stored. For Cloud, a `.html` ending in `slug()` is dropped.
