---
id: cloud
title: Framework Cloud
description: Computer login, project tokens, and token storage
section: features
position: 5
---

## Computer login

[fw_login](ref:fw_login) connects this computer to Framework Cloud through the browser.

```stata
fw_login
```

1. Stata shows a short code and opens the approval page.
2. Sign in, or create a free account, and approve the computer.
3. Stata stores the new token and prints the account it connected.

The code lasts as long as the server allows: 20 minutes on Framework Cloud. Press Break to stop waiting. Batch mode never opens a browser. Open the printed link yourself, or use `nobrowser` anywhere.

```stata
fw_login, nobrowser
```

`url()` connects to another server, such as a self-hosted one. The server is remembered in `cloud.yml` in the Framework configuration folder.

```stata
fw_login, url("https://cloud.example.org")
```

## Token storage

The token goes in the system keyring when there is one:

- **macOS:** the login keychain
- **Linux:** the Secret Service, through `secret-tool`, when the service answers. `secret-tool` alone is not enough: many servers have it but run no Secret Service.
- **Windows:** the Credential Manager

R, Python, and `fw` use the same keyring entry, so one login serves all of them. Without a keyring, the token goes in a private file in the Framework configuration folder: `FW_CONFIG_HOME`, else `$XDG_CONFIG_HOME/framework`, else `~/.config/framework`. Python and `fw` read that file too.

The token never appears in Stata's Results window, macros, or logs. A small shell or PowerShell script reads it and hands it to curl in a private header file.

## Logout

[fw_logout](ref:fw_logout) removes the token for a server from the keyring and from the token files Python and `fw` use. It first revokes the token on the server. When the server cannot be reached, it still removes the token here and says to revoke it on the server's tokens page. A token in `FW_CLOUD_TOKEN` is neither removed nor revoked. R keeps a separate token file, and `fw_logout` names it when it exists.

```stata
fw_logout
```

## Project tokens

`fw_login` connects only the computer. Publishing to Cloud and the integrity ledger use the project token, `FW_PROJECT_TOKEN`, in the project's `.env` file. With the ledger on and no project token, `fw_save` saves the data and says it skipped the push. See [Publishing](guide:publishing#framework-cloud).

## Setup check

[fw_setup](ref:fw_setup) reports the server, whether this computer is connected, and where the token is stored. `nonetwork` skips the request to the server.
