* Example 1: a project and its path globals.
* Run it from any folder. It builds a small project in Stata's temporary folder.

clear
tempfile base
local project = subinstr("`base'", "\", "/", .) + "-example"
mkdir "`project'"
mkdir "`project'/settings"

* A minimal settings file, as R, Python, or fw would write it.
tempname fh
file open `fh' using "`project'/settings.yml", write text replace
file write `fh' "default:" _n
file write `fh' "  project:" _n
file write `fh' "    name: example-study" _n
file write `fh' "  directories:" _n
file write `fh' "    inputs_raw: inputs/raw" _n
file write `fh' "    inputs_final: inputs/final" _n
file write `fh' "    outputs_tables: outputs/tables" _n
file write `fh' "    outputs_figures: outputs/figures" _n
file write `fh' "  publish:" _n
file write `fh' "    default: local" _n
file write `fh' "    destinations:" _n
file write `fh' "      local:" _n
file write `fh' "        driver: folder" _n
file write `fh' "        path: published" _n
file write `fh' "        visibility: private" _n
file close `fh'

cd "`project'"
fw_project

* Every folder has a global. Paths work on any computer.
display "$fw_inputs_raw"
display "$fw_outputs_tables"

* Keep the project for the next examples.
global FW_EXAMPLE_PROJECT "`project'"
