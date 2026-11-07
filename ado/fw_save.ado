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

    local fw_sha ""
    if "`fw_record'" != "" {
        mata: fw_integrity_record(st_local("fw_root"), st_local("fw_record"), st_local("fw_path"), "", st_local("sig"), `locked')
        mata: st_local("live", strofreal(fw_ledger_live()))
        if `live' {
            capture noisily mata: fw_ledger_push(st_local("fw_root"), st_local("fw_record"), st_local("fw_sha"), st_local("fw_path"))
        }
    }
    mata: st_local("rel", fw_relpath(st_local("fw_path"), st_local("fw_root")))
    local short = substr("`fw_sha'", 1, 12)
    if "`short'" != "" local short " (SHA-256 `short'…)"
    display as text `"Saved {res}`name'{txt} to `rel'`short'"'
    if "`fw_record'" != "" & "`fw_sha'" == "" {
        display as text "No SHA-256 tool was found. Framework recorded the datasignature only. Run fw_setup for details."
    }
    return local name `"`name'"'
    return local path `"`fw_path'"'
    return local type `"`fw_type'"'
    return local sha256 `"`fw_sha'"'
    return local datasignature `"`sig'"'
    return scalar locked = `locked'
end
