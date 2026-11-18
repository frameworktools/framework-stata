---
id: cloud
title: Framework Cloud
description: Workstation login, keyring storage, logout, and project tokens
section: features
position: 6
---

## Workstation login

[fw_login](ref:fw_login) authenticates your computer with Framework Cloud through the browser:

```stata
fw_login
```

1. Stata prints a verification code and opens the approval URL.
2. Sign in to Framework Cloud and approve the device.
3. Stata stores the issued token and prints the connected account name.

Device codes remain valid for 20 minutes on `framework.pub`. Press Break to cancel polling. Batch sessions never launch a browser; open the printed URL manually, or pass `nobrowser` in interactive sessions:

```stata
fw_login, nobrowser
```

Pass `url()` to connect to a self-hosted Framework Cloud server. Stata records the server URL in `cloud.yml` inside the Framework configuration directory. Account commands (`fw_logout` and `fw_setup`) check `url()`, then `FW_CLOUD_URL`, then the newer `cloud.yml` written by `fw` or R. `fw_login` checks the same, then names `https://framework.pub` in its notice before connecting.

Cloud publishing and integrity ledger updates read `FW_CLOUD_URL` from the project's `.env` file first, then the process environment, then the saved login server. A project whose `.env` has `FW_PROJECT_TOKEN` but no `FW_CLOUD_URL` never uses the saved login. The token belongs to one server, and `.env` does not name it, so these commands stop and ask for `FW_CLOUD_URL`. When `fw`'s and R's `cloud.yml` name different servers, projects without a token also stop rather than guess. `fw project link` writes `FW_PROJECT_TOKEN` and `FW_CLOUD_URL` to `.env`. Stata does not link projects itself.

With nothing set, commands stop with an error. Stata never falls back to `https://framework.pub` except in `fw_login`.

```stata
fw_login, url("https://cloud.example.org")
```

## Token storage

Stata stores account tokens in the operating system keyring whenever one is available:

- **macOS:** Login Keychain
- **Linux:** Secret Service via `secret-tool` (verified with an active D-Bus session, since headless servers often install `secret-tool` without a running keyring daemon)
- **Windows:** Credential Manager

R, Python, and `fw` share the same keyring entry, so signing in once authenticates all four tools. When no keyring is available, Stata writes a mode-restricted file inside the Framework configuration directory (`FW_CONFIG_HOME`, else `$XDG_CONFIG_HOME/framework`, else `~/.config/framework`), which `framework-py` and `fw` also read.

Account tokens never enter Stata's Results window, macros, or log files. A shell or PowerShell helper reads the credential directly and passes it to `curl` through a temporary header file.

## Logout

[fw_logout](ref:fw_logout) revokes the server token and deletes it from the system keyring and shared token files. If the server is unreachable, `fw_logout` deletes the local credential and reminds you to revoke the token under **Account > Computers & API tokens**. Environment tokens in `FW_CLOUD_TOKEN` are left untouched. When R's separate fallback token file exists, `fw_logout` prints its path.

```stata
fw_logout
```

## Project tokens

`fw_login` authenticates the computer rather than individual projects. Publishing artifacts to Cloud and pushing ledger hashes require `FW_PROJECT_TOKEN` in the project's `.env` file. If `cloud_ledger: live` is set without `FW_PROJECT_TOKEN`, `fw_save` writes the local dataset and notes that the Cloud ledger push was skipped. See [Publishing](guide:publishing#framework-cloud).

## Setup check

[fw_setup](ref:fw_setup) displays the active server URL, connection state, and credential storage backend. Pass `nonetwork` to skip live token verification against the server.
