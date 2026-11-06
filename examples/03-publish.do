* Example 3: publish a table and a report to a local folder.
* Run 01-project.do first. The project's default destination is a folder,
* so nothing leaves this computer.

cd "$FW_EXAMPLE_PROJECT"
fw_project, quietly

* A summary table.
fw_use inputs.final.analysis, clear
collapse (mean) price_k mpg, by(foreign)
fw_save "outputs/tables/summary.csv", replace
fw_publish "outputs/tables/summary.csv", title("Price and mileage by origin")

* A rendered report: any HTML file, with its _files folder if it has one.
tempname fh
file open `fh' using "$fw_outputs_tables/report.html", write text replace
file write `fh' "<!doctype html><title>Example report</title>" _n
file write `fh' "<h1>Example report</h1><p>Synthetic results from sysuse auto.</p>" _n
file close `fh'
fw_publish "$fw_outputs_tables/report.html", title("Example report") slug(report)

* A figure. graph export works in batch mode too. It does not create folders.
capture mkdir "$fw_outputs_figures"
scatter price_k mpg
graph export "$fw_outputs_figures/price.png", replace
fw_publish "$fw_outputs_figures/price.png", title("Price and mileage")

* Open published/index.html in a browser to see every artifact.
display "Published to: $fw_root/published"
