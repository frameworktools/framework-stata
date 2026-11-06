* settings.do: paths for example-study
global root `"`c(pwd)'"'
capture confirm file `"$root/settings.do"'

* Folders
global do `"$root/do"'
global inputs_raw `"$root/inputs/raw"'
global outputs_figures `"$root/outputs/figures"'
