* Capture the SMCL logs that tests/core/test_10_snippet.do splits.
* Each log is what fw_snippet begin records, up to and including the
* fw_snippet end line. Run from the repository root:
*     stata -b do tests/fixtures/snippets/capture.do

version 14
clear all
set more off
set linesize 80
adopath ++ "ado"
local here "tests/fixtures/snippets"
sysuse auto, clear

capture program drop snip_open
program define snip_open
    capture log close fw_snippet
    quietly log using `"`1'"', replace smcl name(fw_snippet)
end

snip_open `here'/regress.smcl
regress price mpg i.foreign
fw_snippet end, nopublish saving(`here'/scratch.json, replace)

snip_open `here'/tabulate.smcl
tabulate rep78 foreign
list make price in 1/3
fw_snippet end, nopublish saving(`here'/scratch.json, replace)

snip_open `here'/continued.smcl
regress price mpg ///
    weight ///
    length, noheader
fw_snippet end, nopublish saving(`here'/scratch.json, replace)

snip_open `here'/error.smcl
capture noisily regress price nosuchvar
display "after the error"
fw_snippet end, nopublish saving(`here'/scratch.json, replace)

snip_open `here'/quietly.smcl
quietly summarize price
quietly {
    summarize mpg
    noisily display "inside"
}
* a comment
display r(mean)
fw_snippet end, folded nopublish saving(`here'/scratch.json, replace)

snip_open `here'/loop.smcl
forvalues i = 1/2 {
    display "i is `i'"
}
foreach v in price mpg {
    quietly summarize `v'
    display "`v': " %9.2f r(mean)
}
display "braces {res} and dollars $S_DATE"
fw_snippet end, nopublish saving(`here'/scratch.json, replace)

erase `here'/scratch.json
