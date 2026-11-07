* Named datasets, checksums, and the integrity record.

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/settings"'
copy `"$FW_TEST_REPO/tests/fixtures/project_yaml/settings.yml"' `"`root'/settings.yml"'
copy `"$FW_TEST_REPO/tests/fixtures/project_yaml/settings/data.yml"' `"`root'/settings/data.yml"'
quietly cd `"`root'"'
fw_project, quietly

t_begin data: fw_save writes a dot-named .dta and records it
capture noisily {
    sysuse auto, clear
    fw_save inputs.final.analysis
    confirm file `"`root'/inputs/final/analysis.dta"'
    assert r(locked) == 1
    assert strlen("`r(sha256)'") == 64
    local sha `"`r(sha256)'"'
    confirm file `"`root'/.framework/stata-integrity.tsv"'
}
t_end `=_rc'

t_begin data: SHA-256 matches the operating system tool
capture noisily {
    tempfile h
    shell sha256sum "`root'/inputs/final/analysis.dta" > "`h'"
    file open fh using "`h'", read text
    file read fh line
    file close fh
    t_eq `"`=substr(`"`line'"', 1, 64)'"' `"`sha'"'
}
t_end `=_rc'

t_begin data: fw_use loads and verifies
capture noisily {
    clear
    fw_use inputs.final.analysis
    assert c(N) == 74
    t_eq `"`r(sha256)'"' `"`sha'"'
}
t_end `=_rc'

t_begin data: fw_save refuses to overwrite without replace
capture noisily {
    capture fw_save inputs.final.analysis
    assert _rc == 602
    fw_save inputs.final.analysis, replace
}
t_end `=_rc'

t_begin data: a changed locked file stops fw_use with error 459
capture noisily {
    * Change the file behind Framework's back.
    sysuse auto, clear
    drop in 1
    save `"`root'/inputs/final/analysis.dta"', replace
    clear
    capture noisily fw_use inputs.final.analysis
    assert _rc == 459
    assert c(N) == 0
}
t_end `=_rc'

t_begin data: check(warn) loads a changed file with a warning
capture noisily {
    fw_use inputs.final.analysis, check(warn) clear
    assert c(N) == 73
}
t_end `=_rc'

t_begin data: unlocked datasets warn and update the record
capture noisily {
    sysuse auto, clear
    fw_save inputs.intermediate.cars, unlocked
    local first `"`r(sha256)'"'
    keep in 1/10
    save `"`root'/inputs/intermediate/cars.dta"', replace
    fw_use inputs.intermediate.cars, clear
    assert c(N) == 10
    fw_use inputs.intermediate.cars, clear
    assert `"`r(sha256)'"' != `"`first'"'
}
t_end `=_rc'

t_begin data: cataloged CSV from the settings catalog
capture noisily {
    capture mkdir `"`root'/inputs"'
    capture mkdir `"`root'/inputs/raw"'
    sysuse auto, clear
    keep make price mpg
    export delimited using `"`root'/inputs/raw/survey.csv"', replace
    clear
    fw_use inputs.raw.survey
    assert c(N) == 74
    t_eq `"`r(type)'"' "csv"
    assert r(locked) == 1
}
t_end `=_rc'

t_begin data: CSV and Excel round trips by path
capture noisily {
    sysuse auto, clear
    fw_save "outputs/tables/cars.csv"
    fw_use "outputs/tables/cars.csv", clear
    assert c(N) == 74
    sysuse auto, clear
    fw_save "outputs/tables/cars.xlsx"
    fw_use "outputs/tables/cars.xlsx", clear
    assert c(N) == 74
}
t_end `=_rc'

t_begin data: unknown folders give a clear error
capture noisily {
    capture fw_save nowhere.at.all
    assert _rc == 601
    capture fw_save justaname
    assert _rc == 601
}
t_end `=_rc'

t_begin data: relative paths fall back to the project root from a subfolder
capture noisily {
    capture mkdir `"`root'/notebooks"'
    quietly cd `"`root'/notebooks"'
    * The file is in the project root, not under notebooks/.
    fw_use "outputs/tables/cars.csv", clear
    assert c(N) == 74
    t_eq `"`r(path)'"' `"`root'/outputs/tables/cars.csv"'
    * fw_save writes to the project root, not a new notebooks/outputs tree.
    fw_save "outputs/tables/from-notebook.csv", replace
    t_eq `"`r(path)'"' `"`root'/outputs/tables/from-notebook.csv"'
    confirm file `"`root'/outputs/tables/from-notebook.csv"'
    mata: assert(!direxists(st_local("root") + "/notebooks/outputs"))
    * A path whose folder exists under the current folder stays there.
    fw_save "here.csv", replace
    t_eq `"`r(path)'"' `"`root'/notebooks/here.csv"'
    fw_use "here.csv", clear
    t_eq `"`r(path)'"' `"`root'/notebooks/here.csv"'
}
local rc = _rc
quietly cd `"`root'"'
t_end `rc'

t_begin data: the 459 message gives the way to accept a change
capture noisily {
    sysuse auto, clear
    fw_save inputs.final.accept, replace
    keep in 1/20
    save `"`root'/inputs/final/accept.dta"', replace
    clear
    set linesize 80
    t_log_begin
    capture noisily fw_use inputs.final.accept
    local rc = _rc
    t_log_end
    set linesize 120
    assert `rc' == 459
    t_log_has "fw_use inputs.final.accept, clear check(accept)"
    t_log_lacks "check(warn)"
    * Each line of the message wraps on its own: the digest stays on one line.
    mata: assert(regexm(fw_readfile(st_global("T_LOG")), "  current:  [0-9a-f]+" + char(10)))
    * The advice works: accept the change, then a strict load passes.
    fw_use inputs.final.accept, clear check(accept)
    fw_use inputs.final.accept, clear
    assert c(N) == 20
}
t_end `=_rc'

t_begin data: check(accept) records a changed locked .dta without rewriting it
capture noisily {
    sysuse auto, clear
    fw_save inputs.final.accept_dta, replace
    local file `"`root'/inputs/final/accept_dta.dta"'
    mata: R0 = fw_integrity_get(st_local("root"), "inputs.final.accept_dta")
    keep in 1/30
    save `"`file'"', replace
    mata: B0 = fw_readfile(st_local("file"))
    mata: st_local("sha0", fw_sha256_file(st_local("file")))
    * recorded_at has one-second resolution.
    sleep 1100
    clear
    t_log_begin
    fw_use inputs.final.accept_dta, clear check(accept)
    * log close clears r(): keep the results first.
    local accepted = r(accepted)
    local locked = r(locked)
    local sha1 `"`r(sha256)'"'
    local sig `"`r(datasignature)'"'
    t_log_end
    assert `accepted' == 1
    assert `locked' == 1
    assert c(N) == 30
    t_eq `"`sha1'"' `"`sha0'"'
    t_log_has "Accepted inputs.final.accept_dta as it is now. Recorded the new SHA-256"
    * The file is not rewritten.
    mata: assert(fw_readfile(st_local("file")) == B0)
    mata: R = fw_integrity_get(st_local("root"), "inputs.final.accept_dta")
    mata: assert(R[3] == st_local("sha0"))
    mata: assert(R[4] == st_local("sig"))
    mata: assert(R[5] == "1")
    mata: assert(R[7] != R0[7])
    fw_use inputs.final.accept_dta, clear
    assert c(N) == 30
    assert r(accepted) == 0
}
t_end `=_rc'

t_begin data: check(accept) records a changed locked CSV without rewriting it
capture noisily {
    local file `"`root'/inputs/raw/survey.csv"'
    sysuse auto, clear
    keep make price
    keep in 1/12
    export delimited using `"`file'"', replace
    mata: B0 = fw_readfile(st_local("file"))
    clear
    capture fw_use inputs.raw.survey
    assert _rc == 459
    fw_use inputs.raw.survey, clear check(accept)
    assert r(accepted) == 1
    assert c(N) == 12
    local sha1 `"`r(sha256)'"'
    mata: assert(fw_readfile(st_local("file")) == B0)
    mata: assert(st_local("sha1") == fw_sha256_file(st_local("file")))
    mata: R = fw_integrity_get(st_local("root"), "inputs.raw.survey")
    mata: assert(R[3] == st_local("sha1"))
    mata: assert(R[5] == "1")
    fw_use inputs.raw.survey, clear
    assert c(N) == 12
    t_eq `"`r(type)'"' "csv"
}
t_end `=_rc'

t_begin data: check(accept) on an unchanged dataset leaves the record alone
capture noisily {
    mata: R0 = fw_integrity_get(st_local("root"), "inputs.raw.survey")
    sleep 1100
    t_log_begin
    fw_use inputs.raw.survey, clear check(accept)
    local accepted = r(accepted)
    t_log_end
    assert `accepted' == 0
    t_log_has "inputs.raw.survey matches its record. Nothing to accept."
    mata: assert(fw_integrity_get(st_local("root"), "inputs.raw.survey") == R0)
}
t_end `=_rc'

t_begin data: check(accept) on a plain file path gives a clear error
capture noisily {
    t_log_begin
    capture noisily fw_use "outputs/tables/cars.csv", clear check(accept)
    local rc = _rc
    t_log_end
    assert `rc' == 198
    t_log_has "check(accept) needs a catalog or dot name"
    t_log_has "Plain file paths are not recorded."
}
t_end `=_rc'

t_begin data: fw_save does not overwrite a locked catalog entry, by name or path
capture noisily {
    local file `"`root'/inputs/raw/survey.csv"'
    mata: B0 = fw_readfile(st_local("file"))
    sysuse auto, clear
    t_log_begin
    capture noisily fw_save inputs.raw.survey, replace
    local rc1 = _rc
    capture noisily fw_save "inputs/raw/survey.csv", replace
    local rc2 = _rc
    capture noisily fw_save `"`file'"', replace outside
    local rc3 = _rc
    t_log_end
    assert `rc1' == 608 & `rc2' == 608 & `rc3' == 608
    t_log_has "dataset: inputs.raw.survey (locked: true in the project settings)"
    mata: assert(fw_readfile(st_local("file")) == B0)
}
t_end `=_rc'

t_begin data: fw_save needs outside for a file outside the project
capture noisily {
    t_tmpdir
    local away `"`r(dir)'"'
    * A settings.do global outside the root is a folder dot names reach.
    t_write `"`root'/settings.do"' `"global shared_away "`away'""'
    fw_project, quietly
    sysuse auto, clear
    t_log_begin
    capture noisily fw_save shared.away.cars
    local rc1 = _rc
    capture noisily fw_save `"`away'/cars.csv"'
    local rc2 = _rc
    t_log_end
    assert `rc1' == 198 & `rc2' == 198
    t_log_has "unless you add the outside option"
    mata: assert(!fileexists(st_local("away") + "/cars.dta"))
    fw_save shared.away.cars, outside
    confirm file `"`away'/cars.dta"'
    fw_save `"`away'/cars.csv"', outside
    confirm file `"`away'/cars.csv"'
}
local rc = _rc
capture erase `"`root'/settings.do"'
fw_project, quietly
t_end `rc'

t_begin data: fw_save to a file path records its checksum, as R does
capture noisily {
    sysuse auto, clear
    fw_save "outputs/tables/recorded.csv", replace
    local sha `"`r(sha256)'"'
    t_eq `"`r(record)'"' "outputs/tables/recorded.csv"
    assert strlen(`"`sha'"') == 64
    mata: R = fw_integrity_get(st_local("root"), "outputs/tables/recorded.csv")
    mata: assert(R[2] == "outputs/tables/recorded.csv")
    mata: assert(R[3] == st_local("sha"))
    mata: assert(R[3] == fw_sha256_file(st_local("root") + "/outputs/tables/recorded.csv"))
    * The same file saved from a subfolder gets the same record name.
    quietly cd `"`root'/notebooks"'
    keep in 1/5
    fw_save "outputs/tables/recorded.csv", replace
    t_eq `"`r(record)'"' "outputs/tables/recorded.csv"
    quietly cd `"`root'"'
    mata: R = fw_integrity_get(st_local("root"), "outputs/tables/recorded.csv")
    mata: assert(R[3] != st_local("sha"))
    * Plain paths are not checked on read, as in R.
    sysuse auto, clear
    export delimited using `"`root'/outputs/tables/recorded.csv"', replace
    fw_use "outputs/tables/recorded.csv", clear
    assert c(N) == 74
}
local rc = _rc
quietly cd `"`root'"'
t_end `rc'

* CSV files written by R: NA, doubles, and long column names.
t_tmpdir
local rp `"`r(dir)'"'
mkdir `"`rp'/inputs"'
mkdir `"`rp'/inputs/raw"'
t_write `"`rp'/settings.yml"' ///
    "default:" ///
    "  directories:" ///
    "    inputs_raw: inputs/raw" ///
    "  data:" ///
    "    inputs:" ///
    "      raw:" ///
    "        visits:" ///
    "          path: inputs/raw/visits.csv" ///
    "          stata_names:" ///
    "            reason_ecmoref_refpicu_any_cardiac: reason_cardiac" ///
    "            log1p_bchecmoref_to_bchadmit_days: log1p_days"
t_write `"`rp'/inputs/raw/visits.csv"' ///
    "ID,SBP Value,reason_ecmoref_refpicu_any_cardiac,log1p_bchecmoref_to_bchadmit_days,group,code,empty" ///
    "1,75.2,NA,0.5,a,-99,NA" ///
    "2,NA,2,NA,NA,7,NA"
quietly cd `"`rp'"'
fw_project, quietly

t_begin data: fw_use reads R's NA as missing and decimals as double
capture noisily {
    t_log_begin
    fw_use "inputs/raw/visits.csv", clear
    local renamed = r(renamed)
    local nacols = r(na_columns)
    t_log_end
    confirm double variable sbpvalue
    assert sbpvalue[1] == 75.2
    assert missing(sbpvalue[2])
    confirm numeric variable reason_ecmoref_refpicu_any_cardi
    assert missing(reason_ecmoref_refpicu_any_cardi[1]) & reason_ecmoref_refpicu_any_cardi[2] == 2
    confirm string variable group
    t_eq `"`=group[2]'"' ""
    confirm numeric variable empty
    assert missing(empty[1]) & missing(empty[2])
    assert `nacols' == 5
    * Renamed columns are listed, old name and new; lowercasing alone is not.
    assert `renamed' == 3
    t_log_has "Warning: Stata renamed 3 columns of visits.csv on import:"
    t_log_has "reason_ecmoref_refpicu_any_cardiac"
    t_log_has "-> reason_ecmoref_refpicu_any_cardi  (longer than 32 characters)"
    t_log_has "SBP Value"
    t_log_lacks "ID "
}
t_end `=_rc'

t_begin data: fw_use asfloat and na() keep the old behavior on request
capture noisily {
    fw_use "inputs/raw/visits.csv", clear asfloat
    confirm float variable sbpvalue
    assert sbpvalue[1] == float(75.2)
    fw_use "inputs/raw/visits.csv", clear na("")
    confirm string variable sbpvalue
    t_eq `"`=group[2]'"' "NA"
    assert r(na_columns) == 0
    fw_use "inputs/raw/visits.csv", clear na("NA" "-99")
    confirm numeric variable code
    assert missing(code[1]) & code[2] == 7
    capture fw_use "inputs/raw/visits.csv", clear options(asfloat)
    assert _rc == 0
    confirm float variable sbpvalue
}
t_end `=_rc'

t_begin data: catalog stata_names name the columns, and fw_save writes them back
capture noisily {
    t_log_begin
    fw_use inputs.raw.visits, clear
    local renamed = r(renamed)
    t_log_end
    confirm numeric variable reason_cardiac log1p_days
    t_eq `"`: variable label reason_cardiac'"' "reason_ecmoref_refpicu_any_cardiac"
    assert `renamed' == 1
    t_log_lacks "-> reason_ecmoref"
    * The catalog entry is unlocked: save it and read the header R sees.
    fw_save inputs.raw.visits, replace
    mata: L = fw_readlines(st_local("rp") + "/inputs/raw/visits.csv")
    mata: assert(strpos(L[1], "reason_ecmoref_refpicu_any_cardiac") > 0)
    mata: assert(strpos(L[1], "log1p_bchecmoref_to_bchadmit_days") > 0)
    mata: assert(strpos(L[1], "reason_cardiac") == 0)
    fw_use inputs.raw.visits, clear
    confirm numeric variable reason_cardiac log1p_days
}
t_end `=_rc'

t_begin data: a bad stata_names entry gives a clear error
capture noisily {
    t_write `"`rp'/settings.yml"' ///
        "default:" ///
        "  data:" ///
        "    inputs:" ///
        "      raw:" ///
        "        visits:" ///
        "          path: inputs/raw/visits.csv" ///
        "          stata_names:" ///
        "            group: 1group"
    fw_project, quietly
    capture fw_use inputs.raw.visits, clear
    assert _rc == 198
}
t_end `=_rc'
quietly cd `"`root'"'
fw_project, quietly

quietly cd `"$FW_TEST_REPO"'
