*! fw_dag: publish a causal DAG
*! Part of the framework package
program define fw_dag, rclass
    version 14
    local cmdline `"fw_dag `0'"'
    syntax [anything(name=paths id="paths")] [using/] [, EXPosure(string asis) OUTcome(string asis) ///
        LATent(string asis) ADJusted(string asis) SELected(string asis) LABels(string asis) ///
        noVARLabels noCODE SLUG(string) TItle(string) DESCription(string) TO(string) ///
        VISibility(string) PRIVate INCLUDEPRIVate SAVing(string asis) noPUBlish]
    local nocode `code'
    _fw_init

    if `"`using'"' != "" & `"`paths'"' != "" {
        display as error "Give paths or a DAGitty file with using, not both."
        exit 198
    }
    if `"`using'"' != "" & `"`exposure'`outcome'`latent'`adjusted'`selected'"' != "" {
        display as error "A DAGitty file sets its own roles. Mark them in the file, as in smoking [exposure], or give paths instead of using."
        exit 198
    }
    local visibility = lower(`"`visibility'"')
    if !inlist(`"`visibility'"', "", "public", "unlisted", "private") {
        display as error "visibility() must be public, unlisted, or private."
        exit 198
    }
    if "`private'" != "" & !inlist(`"`visibility'"', "", "private") {
        display as error "The private option means visibility(private). It cannot go with visibility(`visibility')."
        exit 198
    }
    if "`private'" != "" local visibility private
    local savepath
    local savereplace 0
    if `"`saving'"' != "" {
        gettoken savepath saveopts : saving, parse(",")
        local saveopts = trim(subinstr(`"`saveopts'"', ",", "", 1))
        if !inlist(`"`saveopts'"', "", "replace") {
            display as error `"saving() takes a file name and, optionally, replace."'
            exit 198
        }
        local savereplace = (`"`saveopts'"' == "replace")
        mata: st_local("savepath", fw_abs(st_local("savepath")))
        capture confirm file `"`savepath'"'
        if !_rc & !`savereplace' {
            display as error `"`savepath' already exists. Use saving("`savepath'", replace)."'
            exit 602
        }
    }
    if "`publish'" == "nopublish" & `"`savepath'"' == "" {
        display as error "nopublish needs saving(), or the DAG goes nowhere."
        exit 198
    }
    if "`publish'" != "nopublish" _fw_need_project

    * The graph: DAGitty text read from a file, or built from the paths.
    if `"`using'"' != "" {
        mata: st_local("using", fw_abs(st_local("using")))
        capture confirm file `"`using'"'
        if _rc {
            display as error `"File not found: `using'"'
            exit 601
        }
        mata: st_local("fw_dag_text", fw_dag_trim(fw_readfile(st_local("using"))))
        mata: fw__dag_nodes = J(0, 1, "")
        local fw_dag_nodes .
        local fw_dag_edges .
        * The code that built a file is not this command.
        local code
        if `"`slug'"' == "" mata: st_local("slug", fw_stem(st_local("using")))
    }
    else {
        mata: fw_dag_build(st_local("paths"), st_local("exposure"), st_local("outcome"), ///
            st_local("latent"), st_local("adjusted"), st_local("selected"))
        mata: st_local("code", fw_dag_cmdline(st_local("cmdline")))
        if "`nocode'" != "" local code
        if `"`slug'"' == "" {
            * The first exposure and outcome name the artifact, else dag.
            gettoken first1 : exposure
            gettoken first2 : outcome
            mata: st_local("slug", fw_slug(st_local("first1") + " " + st_local("first2")))
            local slug = cond(`"`slug'"' == "", "dag", "dag-`slug'")
        }
    }
    mata: st_local("labjson", fw_dag_labels(st_local("labels"), "`varlabels'" != "novarlabels"))

    display as text "DAGitty model:"
    mata: fw_dag_show(st_local("fw_dag_text"))

    * A file with nothing to add goes as it is. Anything else is dag.json.
    local asis = (`"`using'"' != "" & `"`labjson'"' == "")
    mata: st_local("scratch", fw_scratch())
    local file `"`scratch'/dag.json"'
    if `asis' local file `"`using'"'

    capture noisily {
        if !`asis' mata: fw_dag_write(st_local("file"), st_local("fw_dag_text"), st_local("labjson"), st_local("code"))
        if `"`savepath'"' != "" {
            mata: st_local("saveext", fw_ext(st_local("savepath")))
            if "`saveext'" == ".dagitty" mata: fw_writefile(st_local("savepath"), st_local("fw_dag_text") + fw_nl())
            else quietly copy `"`file'"' `"`savepath'"', replace
            display as text `"Saved the DAG to `savepath'"'
        }
        if "`publish'" != "nopublish" {
            * The private-path check applies to the DAGitty file, not to the
            * scratch copy Stata wrote.
            local incpriv `includeprivate'
            if !`asis' {
                if `"`using'"' != "" & "`includeprivate'" == "" {
                    mata: st_local("nflag", strofreal(rows(fw_private_flagged(st_local("using")))))
                    if `nflag' {
                        display as error `"`using' has 'private' in its path. Review it, then add the includeprivate option to publish it."'
                        exit 198
                    }
                }
                local incpriv includeprivate
            }
            fw_publish `"`file'"', slug(`"`slug'"') title(`"`title'"') description(`"`description'"') ///
                to(`"`to'"') visibility(`"`visibility'"') kind(dag) `incpriv'
        }
    }
    local rc = _rc
    mata: fw_scratch_done(st_local("scratch"))
    if `rc' exit `rc'
    if "`publish'" != "nopublish" return add
    return local dagitty `"`fw_dag_text'"'
    return local file `"`savepath'"'
    return scalar nodes = `fw_dag_nodes'
    return scalar edges = `fw_dag_edges'
end
