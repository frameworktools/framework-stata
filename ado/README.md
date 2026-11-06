# Package files

Everything in this folder is installed by `net install framework`.

`net install` keeps only Stata file types. Three files are not Stata code
but ship with an `.ihlp` extension so they install:

| File | Contents |
|---|---|
| `fw_cloud_sh.ihlp` | The macOS and Linux shell script for Framework Cloud requests |
| `fw_cloud_ps1.ihlp` | The Windows PowerShell script for the same requests |
| `fw_reader_html.ihlp` | The offline artifact reader, copied from framework-py |

Stata copies the scripts to `.sh` and `.ps1` files in a private temporary
folder before running them. Check the shell script with `sh -n fw_cloud_sh.ihlp`.
