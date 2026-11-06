* Example 2: named datasets with integrity checks.
* Run 01-project.do first.

cd "$FW_EXAMPLE_PROJECT"
fw_project, quietly

* Save a raw dataset under a name. Framework records its checksum.
sysuse auto, clear
fw_save inputs.raw.cars, replace

* Load it by name. Framework checks the file has not changed.
fw_use inputs.raw.cars, clear

* Build an analysis file. Unlocked datasets may change between runs.
generate price_k = price / 1000
label variable price_k "Price (thousands of dollars)"
fw_save inputs.final.analysis, replace unlocked

* Other formats follow the extension.
fw_save "outputs/tables/cars.csv", replace
