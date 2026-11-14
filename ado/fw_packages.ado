*! fw_packages: list and install the packages a project lists in its settings
*! Part of the framework package
program define fw_packages, rclass
    version 14
    gettoken sub rest : 0, parse(" ,")
    if inlist(`"`sub'"', "list", "install", "update") local 0 `"`rest'"'
    else local sub list
    syntax [namelist(name=only)] [, Quietly]
    _fw_need_project
    mata: fw_packages_locals()

    * Check the names given against the settings.
    local all
    forvalues i = 1/`fw_n' {
        local all `all' `fw_name`i''
    }
    local unknown : list only - all
    if "`unknown'" != "" {
        display as error `"Not in the project's packages: `unknown'"'
        exit 111
    }

    * Each package's state: installed, missing, or skipped (with the reason).
    local where = cond("`fw_plus'" != "", `"`fw_plus'"', `"`c(sysdir_plus)'"')
    local installed
    local missing
    local skipped
    forvalues i = 1/`fw_n' {
        if "`only'" != "" & !`: list fw_name`i' in only' continue
        if `"`fw_problem`i''"' != "" {
            local state`i' skipped
            local skipped `skipped' `fw_name`i''
            continue
        }
        mata: st_local("have", strofreal(fw_package_installed(st_local("where"), st_local("fw_name`i'"))))
        if !`have' {
            local state`i' missing
            local missing `missing' `fw_name`i''
        }
        else {
            local state`i' installed
            local installed `installed' `fw_name`i''
        }
    }

    local failed
    local firstrc 0
    if "`sub'" != "list" {
        local todo = cond("`sub'" == "update", "`installed' `missing'", "`missing'")
        local todo : list retokenize todo
        if "`todo'" == "" {
            if "`quietly'" == "" & `fw_n' {
                display as text "Every package is installed."
            }
        }
        else {
            local oldplus `"`c(sysdir_plus)'"'
            if "`fw_plus'" != "" {
                mata: fw_mkdirp(st_local("fw_plus"))
                quietly sysdir set PLUS `"`fw_plus'"'
            }
            forvalues i = 1/`fw_n' {
                if !`: list fw_name`i' in todo' continue
                local opts = cond("`sub'" == "update", "replace", "")
                if "`quietly'" == "" display as text _n "Installing `fw_name`i'' (`fw_source`i'')"
                if "`fw_source`i''" == "ssc" {
                    capture noisily ssc install `fw_name`i'', `opts'
                }
                else {
                    capture noisily net install `fw_name`i'', from(`"`fw_from`i''"') `opts'
                }
                if _rc == 1 {
                    * Break: put PLUS back and stop.
                    if "`fw_plus'" != "" quietly sysdir set PLUS `"`oldplus'"'
                    exit 1
                }
                if _rc {
                    if !`firstrc' local firstrc = _rc
                    local failed `failed' `fw_name`i''
                }
                else {
                    local state`i' installed
                    local missing : list missing - fw_name`i'
                    if !`: list fw_name`i' in installed' local installed `installed' `fw_name`i''
                }
            }
            if "`fw_plus'" != "" quietly sysdir set PLUS `"`oldplus'"'
        }
    }

    if "`quietly'" == "" {
        if !`fw_n' {
            display as text "The project lists no packages. Add them under packages: in the project settings."
        }
        else {
            local file = cond(`"`fw_settings_file'"' != "", `"`fw_settings_file'"', "the project settings")
            display as text _n `"Packages in `file'"' _c
            if "`fw_plus'" != "" display as text ", installed in the project's ado/plus folder"
            else display as text ""
            forvalues i = 1/`fw_n' {
                if "`only'" != "" & !`: list fw_name`i' in only' continue
                local state `state`i''
                if `: list fw_name`i' in failed' local state failed
                local how = cond("`state'" == "installed", "result", cond("`state'" == "skipped", "text", "error"))
                display as text "  `fw_name`i''{col 24}`fw_source`i''{col 33}" as `how' "`state'" _c
                if "`state'" == "skipped" display as text `": `fw_problem`i''"'
                else display ""
            }
            if "`missing'" != "" & "`sub'" == "list" {
                display as text _n "Install the missing packages with: fw_packages install"
            }
        }
    }

    return local packages `"`all'"'
    return local installed `"`: list retokenize installed'"'
    return local missing `"`: list retokenize missing'"'
    return local skipped `"`: list retokenize skipped'"'
    return local failed `"`: list retokenize failed'"'
    return local plus `"`where'"'
    if `firstrc' {
        display as error `"Could not install: `: list retokenize failed'"'
        exit `firstrc'
    }
end
