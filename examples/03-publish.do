* Example 3: publish a table and a report to a local folder.
* Run 01-project.do first. The project's default destination is a folder,
* so nothing leaves this computer.

cd "$FW_EXAMPLE_PROJECT"
fw_project, quietly

* A summary table, saved with free-text headers and recorded.
fw_use inputs.final.analysis, clear
collapse (mean) price_k mpg, by(foreign)
fw_table summary, headers("Origin" "Mean price, thousands" "Mean mileage, mpg")
fw_publish "`r(path)'", title("Price and mileage by origin")

* A rendered report: any HTML file, with its _files folder if it has one.
tempname fh
file open `fh' using "$fw_outputs_tables/report.html", write text replace
file write `fh' "<!doctype html><title>Example report</title>" _n
file write `fh' "<h1>Example report</h1><p>Synthetic results from sysuse auto.</p>" _n
file close `fh'
fw_publish "$fw_outputs_tables/report.html", title("Example report") slug(report)

* A figure. fw_graph exports it to the figures folder and records it. It
* works in batch mode too.
scatter price_k mpg
fw_graph price
fw_publish "`r(path)'", title("Price and mileage")

* Open published/index.html in a browser to see every artifact.
display "Published to: $fw_root/published"
