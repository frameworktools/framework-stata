# Package files

`net install framework` installs every file in this directory.

Because `net install` restricts extensions to Stata file types, three non-Stata assets use the `.ihlp` extension for distribution:

| File | Contents |
|---|---|
| `fw_cloud_sh.ihlp` | macOS and Linux shell helper for Framework Cloud requests |
| `fw_cloud_ps1.ihlp` | Windows PowerShell helper for Framework Cloud requests |
| `fw_reader_html.ihlp` | Offline HTML artifact reader shared with `framework-py` |

Before execution, Stata copies the helper scripts to `.sh` or `.ps1` files inside a private temporary directory. Validate shell syntax with `sh -n fw_cloud_sh.ihlp`.
