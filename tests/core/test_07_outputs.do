* Tables and figures: fw_table and fw_graph, their folders, and their records.

t_tmpdir
local root `"`r(dir)'"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  project_name: outputs-test" ///
    "  directories:" ///
    "    inputs_raw: inputs/raw" ///
    "    outputs_tables: outputs/tables" ///
    "    outputs_figures: outputs/figures"
quietly cd `"`root'"'
fw_project, quietly

t_begin outputs: numbers are written as R writes them
capture noisily {
    mata: st_local("v", fw_csv_num(1.5, 0, "NA") + " " + fw_csv_num(1/3, 0, "NA") + " " + fw_csv_num(-0.25, 0, "NA") + " " + fw_csv_num(., 0, "NA") + " " + fw_csv_num(1e-20, 0, "NA") + " " + fw_csv_num(12, 0, "NA"))
    t_eq "`v'" "1.5 0.3333333333333333 -0.25 NA 1e-20 12"
    * A float 75.2 is written 75.2, not 75.19999695.
    clear
    set obs 1
    generate float f = 75.2
    mata: st_local("v", fw_csv_num(st_data(1, "f"), 1, "NA"))
    t_eq "`v'" "75.2"
}
t_end `=_rc'

t_begin outputs: fw_table writes the data in memory with labels as headers
capture noisily {
    clear
    set obs 3
    generate byte answer = _n
    label define yn 1 "Yes" 2 "No"
    label values answer yn
    generate str10 grp = "a,b" in 1
    replace grp = "NA" in 2
    label variable grp `"Group "A""'
    generate double val = 1.5 in 1
    replace val = 1/3 in 3
    label variable val "Mean (SD), %"
    generate float fv = 75.2 in 1
    replace fv = 0.1 in 2
    replace fv = 3 in 3
    generate d = mdy(1, 2, 2020)
    format d %td
    fw_table summary
    t_eq `"`r(path)'"' `"`root'/outputs/tables/summary.csv"'
    assert r(N) == 3 & r(k) == 5
    local sha `"`r(sha256)'"'
    mata: L = fw_readlines(st_local("root") + "/outputs/tables/summary.csv")
    mata: assert(rows(L) == 4)
    mata: assert(L[1] == `"answer,"Group ""A""","Mean (SD), %",fv,d"')
    mata: assert(L[2] == `"Yes,"a,b",1.5,75.2,2020-01-02"')
    mata: assert(L[3] == `"No,"NA",NA,0.1,2020-01-02"')
    mata: assert(L[4] == "3,,0.3333333333333333,3,2020-01-02")
    * The result is recorded by its path from the project root, as R does.
    mata: R = fw_result_get(st_local("root"), "outputs/tables/summary.csv")
    mata: assert(R[2] == "table" & R[3] == "0")
    mata: assert(R[4] == st_local("sha") & strlen(R[4]) == 64)
    mata: assert(R[4] == fw_sha256_file(st_local("root") + "/outputs/tables/summary.csv"))
    * The data in memory are unchanged.
    assert c(N) == 3 & c(k) == 5
}
t_end `=_rc'

t_begin outputs: headers(), a varlist, if, a subfolder, and Excel
capture noisily {
    fw_table "meeting/table-1" grp val if !missing(val), headers("Group" "95% CI, all patients") format(csv xlsx) nolabel na("")
    confirm file `"`root'/outputs/tables/meeting/table-1.csv"'
    confirm file `"`root'/outputs/tables/meeting/table-1.xlsx"'
    assert r(N) == 2 & r(k) == 2
    mata: L = fw_readlines(st_local("root") + "/outputs/tables/meeting/table-1.csv")
    mata: assert(L[1] == `"Group,"95% CI, all patients""')
    mata: assert(L[2] == `""a,b",1.5"')
    mata: R = fw_result_get(st_local("root"), "outputs/tables/meeting/table-1.xlsx")
    mata: assert(R[2] == "table")
    preserve
    import excel using `"`root'/outputs/tables/meeting/table-1.xlsx"', clear allstring
    t_eq `"`=A[1]'"' "Group"
    t_eq `"`=B[1]'"' "95% CI, all patients"
    t_eq `"`=A[2]'"' "a,b"
    restore
    * A name with an extension picks the format.
    fw_table "plain.xlsx" answer, varnames
    confirm file `"`root'/outputs/tables/plain.xlsx"'
    capture fw_table "plain.xlsx", format(csv)
    assert _rc == 198
}
t_end `=_rc'

t_begin outputs: fw_table saves a matrix with its row and column names
capture noisily {
    matrix M = (1, 2.5 \ 3, .)
    matrix rownames M = mpg weight
    matrix colnames M = b se
    fw_table coefs, matrix(M)
    mata: L = fw_readlines(st_local("root") + "/outputs/tables/coefs.csv")
    mata: assert(L[1] == ",b,se")
    mata: assert(L[2] == "mpg,1,2.5")
    mata: assert(L[3] == "weight,3,NA")
    fw_table coefs2, matrix(M) headers("Term" "Estimate" "SE")
    mata: L = fw_readlines(st_local("root") + "/outputs/tables/coefs2.csv")
    mata: assert(L[1] == "Term,Estimate,SE")
    * Stata's default row names r1, r2 are left out.
    matrix N = (1, 2 \ 3, 4)
    fw_table plain-matrix, matrix(N)
    mata: L = fw_readlines(st_local("root") + "/outputs/tables/plain-matrix.csv")
    mata: assert(L[1] == "c1,c2" & L[2] == "1,2")
}
t_end `=_rc'

t_begin outputs: fw_table errors are clear
capture noisily {
    sysuse auto, clear
    capture noisily fw_table bad make price, headers("Only one")
    assert _rc == 198
    capture noisily fw_table "../escape" make
    assert _rc == 198
    capture noisily fw_table summary, noreplace
    assert _rc == 602
    capture noisily fw_table m, matrix(M) if price > 0
    assert _rc != 0
}
t_end `=_rc'

t_begin outputs: a sensitive project splits private and public tables
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    t_write `"`s'/settings.yml"' ///
        "default:" ///
        "  security:" ///
        "    sensitive: true" ///
        "  directories:" ///
        "    inputs_private_raw: inputs/private/raw" ///
        "    outputs_private_tables: outputs/private/tables" ///
        "    outputs_public_tables: outputs/public/tables"
    quietly cd `"`s'"'
    fw_project, quietly
    sysuse auto, clear
    fw_save "inputs/private/raw/cars.dta", replace
    fw_use "inputs/private/raw/cars.dta", clear
    fw_table counts make price
    t_eq `"`r(path)'"' `"`s'/outputs/private/tables/counts.csv"'
    assert r(public) == 0
    t_log_begin
    fw_table counts make price, public
    local path `"`r(path)'"'
    t_log_end
    t_eq `"`path'"' `"`s'/outputs/public/tables/counts.csv"'
    t_log_has "Warning: this public table comes from data in a file with 'private' in its path:"
    mata: R = fw_result_get(st_local("s"), "outputs/public/tables/counts.csv")
    mata: assert(R[3] == "1")
    * Figures follow the same rule, with default folders.
    sysuse auto, clear
    scatter mpg price
    fw_graph price-mpg, public
    t_eq `"`r(path)'"' `"`s'/outputs/public/figures/price-mpg.png"'
}
local rc = _rc
quietly cd `"`root'"'
fw_project, quietly
t_end `rc'

t_begin outputs: fw_graph exports the current graph and records it
capture noisily {
    sysuse auto, clear
    scatter mpg price
    fw_graph "meeting/price-mpg", format(png pdf)
    confirm file `"`root'/outputs/figures/meeting/price-mpg.png"'
    confirm file `"`root'/outputs/figures/meeting/price-mpg.pdf"'
    t_eq `"`r(path)'"' `"`root'/outputs/figures/meeting/price-mpg.png"'
    mata: R = fw_result_get(st_local("root"), "outputs/figures/meeting/price-mpg.pdf")
    mata: assert(R[2] == "figure" & strlen(R[4]) == 64)
    * PNG width is 300 pixels per inch of the graph's width, as save_figure()'s dpi = 300.
    quietly graph describe
    mata: b = fw_readfile(st_local("root") + "/outputs/figures/meeting/price-mpg.png")
    mata: w = ascii(substr(b, 17, 1)) * 16777216 + ascii(substr(b, 18, 1)) * 65536 + ascii(substr(b, 19, 1)) * 256 + ascii(substr(b, 20, 1))
    mata: assert(w == round(strtoreal(st_global("r(xsize)")) * 300))
    fw_graph "small", width(400)
    mata: b = fw_readfile(st_local("root") + "/outputs/figures/small.png")
    mata: assert(ascii(substr(b, 19, 1)) * 256 + ascii(substr(b, 20, 1)) == 400)
    * A named graph, and the format from the name.
    scatter mpg weight, name(byweight, replace)
    scatter price weight
    fw_graph "weight.svg", name(byweight)
    confirm file `"`root'/outputs/figures/weight.svg"'
    capture noisily fw_graph "weight.svg", noreplace
    assert _rc == 602
    capture noisily fw_graph "x", format(bmp)
    assert _rc == 198
    graph drop byweight
}
t_end `=_rc'

quietly cd `"$FW_TEST_REPO"'
