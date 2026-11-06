*! fw_use: load a named dataset and check its integrity
*! Part of the framework package
program define fw_use, rclass
    version 14
    syntax anything(name=name id="dataset name") [, CLEAR CHECK(string) OPTions(string asis)]
    _fw_need_project
    gettoken name : name
    if "`check'" == "" local check strict
    if !inlist("`check'", "strict", "warn", "off", "accept") {
        display as error "check() must be strict, warn, off, or accept."
        exit 198
    }
    if c(changed) & "`clear'" == "" {
        error 4
    }
    mata: fw_data_resolve(st_local("name"), 0)
    if "`check'" == "accept" & "`fw_record'" == "" {
        display as error "check(accept) needs a catalog or dot name, such as inputs.raw.survey. Plain file paths are not recorded."
        exit 198
    }
    capture confirm file `"`fw_path'"'
    if _rc {
        display as error `"The file for `name' was not found: `fw_path'"'
        exit 601
    }
    mata: fw_integrity_check_file(st_local("fw_root"), st_local("fw_record"), st_local("fw_path"), `fw_locked', st_local("check"))

    if "`fw_type'" == "dta" {
        use `"`fw_path'"', clear `options'
    }
    else if "`fw_type'" == "csv" {
        import delimited using `"`fw_path'"', clear `options'
    }
    else if "`fw_type'" == "tsv" {
        import delimited using `"`fw_path'"', delimiters(tab) clear `options'
    }
    else {
        import excel using `"`fw_path'"', firstrow clear `options'
    }

    quietly datasignature
    local sig `"`r(datasignature)'"'
    capture noisily mata: fw_integrity_check_sig(st_local("fw_root"), st_local("fw_record"), st_local("sig"), `fw_locked', st_local("check"))
    if _rc {
        local rc = _rc
        clear
        exit `rc'
    }
    local fw_accepted 0
    if "`check'" == "accept" {
        * Record the file as it is now. The file itself is not rewritten.
        mata: fw_integrity_accept(st_local("fw_root"), st_local("fw_record"), st_local("fw_path"), st_local("fw_sha"), st_local("sig"), `fw_locked')
        local short = substr("`fw_sha'", 1, 12)
        local what = cond("`short'" == "", "datasignature", "SHA-256 `short'…")
        if `fw_accepted' == 0 {
            display as text `"{res}`name'{txt} matches its record. Nothing to accept."'
        }
        else {
            if `fw_accepted' == 1 display as text `"Accepted {res}`name'{txt} as it is now. Recorded the new `what'."'
            else display as text `"Recorded {res}`name'{txt} as it is now (`what')."'
            mata: st_local("live", strofreal(fw_ledger_live()))
            if `live' {
                capture noisily mata: fw_ledger_push(st_local("fw_root"), st_local("fw_record"), st_local("fw_sha"), st_local("fw_path"))
            }
        }
    }
    * Record the first read, and later reads of unlocked data, as R and Python do.
    else if "`fw_record'" != "" & "`check'" != "off" & !(`fw_locked' & ("`fw_changed'" == "1" | "`fw_sigchanged'" == "1")) {
        mata: fw_integrity_record(st_local("fw_root"), st_local("fw_record"), st_local("fw_path"), st_local("fw_sha"), st_local("sig"), `fw_locked')
    }
    mata: st_local("rel", fw_relpath(st_local("fw_path"), st_local("fw_root")))
    display as text `"Loaded {res}`name'{txt} from `rel' ("' as result c(N) as text " observations)"
    return local name `"`name'"'
    return local path `"`fw_path'"'
    return local type `"`fw_type'"'
    return local sha256 `"`fw_sha'"'
    return local datasignature `"`sig'"'
    return scalar locked = `fw_locked'
    return scalar accepted = (`fw_accepted' > 0)
end
