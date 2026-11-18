*! fw_snippet: publish a do-file's commands and the output they printed
*! Part of the framework package
program define fw_snippet, rclass
    version 14
    gettoken sub 0 : 0, parse(" ,")
    if `"`sub'"' == "begin" {
        _fw_snippet_begin `0'
        exit
    }
    if `"`sub'"' == "end" {
        _fw_snippet_end `0'
        return add
        exit
    }
    if `"`sub'"' == "" display as error "fw_snippet needs begin or end: fw_snippet begin <label>, then fw_snippet end."
    else display as error `"fw_snippet takes begin or end, not `sub'."'
    exit 198
end

program define _fw_snippet_begin
    version 14
    syntax anything(name=label id="label")
    _fw_init
    local label = trim(`"`label'"')
    if `: word count `label'' != 1 | strpos(`"`label'"', `"""') {
        display as error "fw_snippet begin takes one label without spaces, such as fit-ols."
        exit 198
    }
    if strlen(`"`label'"') > 120 {
        display as error "The snippet label can be at most 120 characters."
        exit 198
    }
    capture quietly log query fw_snippet
    if !_rc {
        local open `"`r(filename)'"'
        quietly log close fw_snippet
        mata: st_local("stale", strofreal(fw_snippet_stale(st_local("open"))))
        if !`stale' {
            * Snippets do not nest. The open one goes on.
            quietly log using `"`open'"', append smcl name(fw_snippet)
            display as error `"The snippet $fw__snippet_label is still open. Snippets cannot nest."'
            display as error `"End it with fw_snippet end before fw_snippet begin `label', or discard it with: log close fw_snippet"'
            exit 198
        }
        * The do-file stopped with an error inside that snippet.
        display as text `"Note: closed the snippet $fw__snippet_label, left open when a do-file stopped with an error."'
        if `"$fw__snippet_dir"' != "" mata: fw_scratch_done(st_global("fw__snippet_dir"))
    }
    mata: st_global("fw__snippet_dir", fw_scratch())
    global fw__snippet_label `"`label'"'
    quietly log using `"$fw__snippet_dir/snippet.smcl"', replace smcl name(fw_snippet)
end

program define _fw_snippet_end, rclass
    version 14
    syntax [, FOLDed UNFOLDed noOUTput SLUG(string) TItle(string) DESCription(string) ///
        TO(string) VISibility(string) PRIVate FILE(string) REPOsitory(string) ///
        NOTEbook(string) MODel(string) SAVing(string asis) noPUBlish]
    _fw_init
    capture quietly log query fw_snippet
    if _rc {
        display as error "No snippet is open. Start one with fw_snippet begin <label>."
        exit 198
    }
    local logfile `"`r(filename)'"'

    * Check the options before the log closes, so a mistake loses nothing.
    if "`folded'" != "" & "`unfolded'" != "" {
        display as error "Give folded or unfolded, not both."
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
    if `"`notebook'"' != "" & substr(`"`notebook'"', 1, 8) != "https://" {
        display as error "notebook() takes an https:// address."
        exit 198
    }
    if `"`model'"' != "" & substr(`"`model'"', 1, 8) != "https://" & !regexm(`"`model'"', "^[A-Za-z0-9_-]+$") {
        display as error "model() takes the slug of a model artifact in this project, or an https:// address."
        exit 198
    }
    if `"`repository'"' != "" & !regexm(`"`repository'"', "^https://github[.]com/[^/]+/[^/]+$") {
        display as error "repository() takes a GitHub address, such as https://github.com/owner/repository."
        exit 198
    }
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
        display as error "nopublish needs saving(), or the snippet goes nowhere."
        exit 198
    }

    quietly log close fw_snippet
    local label `"$fw__snippet_label"'
    local dir `"$fw__snippet_dir"'
    global fw__snippet_label
    global fw__snippet_dir
    if `"`label'"' == "" local label snippet
    if `"`dir'"' == "" mata: st_local("dir", fw_scratch())

    * A project gives the do-file's path, the commit, and the publish target.
    local root
    if "`publish'" == "nopublish" {
        capture _fw_need_project
        if !_rc local root `"$fw_root"'
    }
    else {
        _fw_need_project
        local root `"$fw_root"'
    }
    if `"`repository'"' == "" & `"`root'"' != "" {
        mata: st_local("repository", fw_setting(fw_S(), "publish.repository"))
    }

    local json `"`dir'/code_snippet.json"'
    local ok 0
    capture noisily {
        mata: fw_snippet_source(st_local("root"), st_local("file"), st_local("label"))
        if `"`fw_snip_note'"' != "" display as text `"Note: `fw_snip_note'"'
        mata: st_local("commit", fw_snippet_commit(st_local("root")))
        local fold .
        if "`folded'" != "" local fold 1
        if "`unfolded'" != "" local fold 0
        local lines
        if "`fw_snip_from'" != "" local lines `fw_snip_from'-`fw_snip_to'
        mata: fw_snippet_write(st_local("logfile"), st_local("json"), st_local("label"), ///
            "`output'" == "nooutput", st_local("fw_snip_file"), ///
            (strtoreal(st_local("fw_snip_from")), strtoreal(st_local("fw_snip_to"))), ///
            st_local("commit"), st_local("repository"), `fold', st_local("notebook"), st_local("model"))
        if `"`savepath'"' != "" {
            quietly copy `"`json'"' `"`savepath'"', replace
            display as text `"Saved the snippet to `savepath'"'
        }
        local ok 1
        if "`publish'" != "nopublish" {
            if `"`slug'"' == "" local slug `"`label'"'
            * The snippet is a file Stata wrote, so the private-path check
            * does not apply to its scratch path.
            fw_publish `"`json'"', slug(`"`slug'"') title(`"`title'"') description(`"`description'"') ///
                to(`"`to'"') visibility(`"`visibility'"') kind(code_snippet) includeprivate
            local ok 2
        }
    }
    local rc = _rc
    if `rc' {
        * A built snippet that failed to publish stays on disk to retry.
        if `ok' == 1 & "`publish'" != "nopublish" {
            display as error `"The snippet is in `json'. Publish it again with:"'
            display as error `"  fw_publish "`json'", kind(code_snippet) slug(`slug')"'
        }
        else mata: fw_scratch_done(st_local("dir"))
        exit `rc'
    }
    if "`publish'" != "nopublish" {
        return add
    }
    mata: fw_scratch_done(st_local("dir"))
    return local label `"`label'"'
    return local source_file `"`fw_snip_file'"'
    return local lines `"`lines'"'
    return local commit `"`commit'"'
    return local file `"`savepath'"'
    return scalar blocks = `fw_snip_blocks'
    return scalar code_blocks = `fw_snip_code'
    return scalar output_blocks = `fw_snip_output'
end
