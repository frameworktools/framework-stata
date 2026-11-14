*! fw_scaffold: load the project and prepare the Stata session
*! Part of the framework package
program define fw_scaffold, rclass
    version 14
    syntax [, ROOT(string) NOINSTall Quietly]
    _fw_init
    if `"`root'"' == "" local root `"`c(pwd)'"'
    fw_project, root(`"`root'"') quietly
    mata: fw_scaffold_locals()
    local say = cond("`quietly'" == "", "noisily", "quietly")

    `say' display as text "Project: " as result `"$fw_project_name"' as text " (" `"$fw_root"' ")"

    * The project's own packages: PLUS points at ado/plus for the session
    if "`fw_plus'" != "" {
        mata: fw_mkdirp(st_local("fw_plus"))
        quietly sysdir set PLUS `"`fw_plus'"'
        `say' display as text "Packages: ado/plus in the project"
    }
    if `fw_npkg' & "`noinstall'" == "" {
        fw_packages install, quietly
    }

    if "`fw_seed'" != "" {
        set seed `fw_seed'
        `say' display as text "Random seed set to `fw_seed'."
    }

    if "`fw_scheme'" != "" {
        capture set scheme `fw_scheme'
        if _rc {
            display as error "Graph scheme `fw_scheme' not found. The scheme is unchanged."
            local fw_scheme
        }
        else `say' display as text "Graph scheme set to `fw_scheme'."
    }

    * Programs in the function folders load by name, as R sources functions/
    local functions
    forvalues i = 1/`fw_nfunc' {
        quietly adopath ++ `"`fw_func`i''"'
        local functions `"`functions' `"`fw_func`i''"'"'
        `say' display as text "Programs in `fw_funcrel`i''/ load by name."
    }

    if `"`fw_script'"' != "" {
        `say' display as text "Running scaffold.do"
        do `"`fw_script'"'
    }

    return local root `"$fw_root"'
    return local seed "`fw_seed'"
    return local scheme "`fw_scheme'"
    return local plus `"`fw_plus'"'
    return local functions `"`: list retokenize functions'"'
end
