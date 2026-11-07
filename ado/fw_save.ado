*! fw_save: save a named dataset and record its integrity
*! Part of the framework package
program define fw_save, rclass
    version 14
    syntax anything(name=name id="dataset name") [, REPLACE UNLOCKED OUTside OPTions(string asis)]
    _fw_need_project
    gettoken name : name
    mata: fw_data_resolve(st_local("name"), 1)
    mata: fw_save_guard(st_local("fw_path"), "`outside'" != "")
    capture confirm file `"`fw_path'"'
    if !_rc & "`replace'" == "" {
        display as error `"`fw_path' already exists. Add the replace option to overwrite it."'
        exit 602
    }
    mata: fw_mkdirp(fw_dirname(st_local("fw_path")))
    quietly datasignature
    local sig `"`r(datasignature)'"'
    local locked = ("`unlocked'" == "")

    if "`fw_type'" == "dta" {
        quietly save `"`fw_path'"', `replace' `options'
    }
    else if "`fw_type'" == "csv" {
        quietly export delimited using `"`fw_path'"', `replace' `options'
    }
    else if "`fw_type'" == "tsv" {
        quietly export delimited using `"`fw_path'"', delimiter(tab) `replace' `options'
    }
    else {
        quietly export excel using `"`fw_path'"', firstrow(variables) `replace' `options'
    }
    * A catalog entry with stata_names gets the file's own column names back.
    if `fw_cataloged' & inlist("`fw_type'", "csv", "tsv") {
        mata: fw_csv_restore_names(st_local("fw_record"), st_local("fw_path"), "`fw_type'" == "csv" ? "," : char(9))
    }

    local fw_sha ""
    * A plain file path is recorded by its path from the project root, as R
    * records data_save() to a path. fw_use does not check plain paths.
    if "`fw_record'" == "" {
        mata: st_local("fw_record", fw_path_record(st_local("fw_path"), st_local("fw_root")))
    }
    if "`fw_record'" != "" {
        mata: fw_integrity_record(st_local("fw_root"), st_local("fw_record"), st_local("fw_path"), "", st_local("sig"), `locked')
        mata: st_local("live", strofreal(fw_ledger_live()))
        if `live' {
            capture noisily mata: fw_ledger_push(st_local("fw_root"), st_local("fw_record"), st_local("fw_sha"), st_local("fw_path"))
        }
    }
    * The file the data in memory came from, for fw_publish, estimates.
    * c(filename) tells whether a plain use or save has replaced it since.
    global fw__data_source `"`fw_path'"'
    global fw__data_filename `"`c(filename)'"'
    mata: st_local("rel", fw_relpath(st_local("fw_path"), st_local("fw_root")))
    local short = substr("`fw_sha'", 1, 12)
    if "`short'" != "" local short " (SHA-256 `short'…)"
    display as text `"Saved {res}`name'{txt} to `rel'`short'"'
    if "`fw_sha'" == "" {
        display as text "No SHA-256 tool was found. Framework recorded the datasignature only. Run fw_setup for details."
    }
    return local name `"`name'"'
    return local record `"`fw_record'"'
    return local path `"`fw_path'"'
    return local type `"`fw_type'"'
    return local sha256 `"`fw_sha'"'
    return local datasignature `"`sig'"'
    return scalar locked = `locked'
end
