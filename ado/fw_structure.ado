*! fw_structure: show or publish a project's folder tree
*! Part of the framework package
program define fw_structure, rclass
    version 14
    syntax [anything(name=paths id="paths")] [, DEPth(integer -1) EXClude(string asis) ///
        NOTEs(string asis) OPen(string asis) HIGHlight(string asis) IGNored(string) ///
        PUBlish SLUG(string) TItle(string) DESCription(string) TO(string) ///
        VISibility(string) PRIVate DISPlay(string) SAVing(string asis)]
    _fw_init

    if `depth' != -1 & `depth' < 1 {
        display as error "depth() takes a number of levels, 1 or more."
        exit 198
    }
    local ignored = lower(`"`ignored'"')
    if !inlist(`"`ignored'"', "", "rules", "hide") {
        display as error "ignored() takes rules or hide."
        exit 198
    }
    local hide = (`"`ignored'"' == "hide")
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
    if "`publish'" == "" & `"`slug'`title'`description'`to'`visibility'`display'"' != "" {
        display as error "slug(), title(), description(), to(), visibility(), private, and display() go with publish."
        exit 198
    }
    if `"`display'"' != "" mata: fw__display = fw_display_parse(st_local("display"))
    local savepath
    if `"`saving'"' != "" {
        gettoken savepath saveopts : saving, parse(",")
        local saveopts = trim(subinstr(`"`saveopts'"', ",", "", 1))
        if !inlist(`"`saveopts'"', "", "replace") {
            display as error `"saving() takes a file name and, optionally, replace."'
            exit 198
        }
        mata: st_local("savepath", fw_abs(st_local("savepath")))
        capture confirm file `"`savepath'"'
        if !_rc & `"`saveopts'"' != "replace" {
            display as error `"`savepath' already exists. Use saving("`savepath'", replace)."'
            exit 602
        }
    }
    _fw_need_project

    mata: fw_tree_build(st_local("paths"), `depth' == -1 ? . : `depth', st_local("exclude"), `hide')
    mata: fw_tree_marks(st_local("notes"), st_local("open"), st_local("highlight"))
    if "`publish'" != "" & `fw_tree_private' {
        display as error `"`fw_tree_base' is a private folder. Its structure does not publish."'
        exit 198
    }
    mata: fw_tree_show(st_local("fw_tree_root"), "`publish'" != "")

    if `"`slug'"' == "" {
        mata: st_local("slug", fw_slug(st_local("fw_tree_base")))
        local slug = cond(`"`slug'"' == "", "structure", "structure-`slug'")
    }
    if `"`title'"' == "" local title `"`fw_tree_root' structure"'

    mata: st_local("scratch", fw_scratch())
    mata: st_local("file", st_local("scratch") + "/" + fw_slug(st_local("slug")) + ".json")
    capture noisily {
        mata: fw_tree_write(st_local("file"), st_local("fw_tree_root"), st_local("fw_tree_base"), st_local("fw_tree_method"))
        if `"`savepath'"' != "" {
            quietly copy `"`file'"' `"`savepath'"', replace
            display as text `"Saved the tree to `savepath'"'
        }
        if "`publish'" != "" {
            * The tree holds names only, and private folders publish as
            * stubs, so the scratch file needs no private-path check.
            fw_publish `"`file'"', slug(`"`slug'"') title(`"`title'"') description(`"`description'"') ///
                to(`"`to'"') visibility(`"`visibility'"') kind(tree) includeprivate display(`"`display'"')
        }
    }
    local rc = _rc
    mata: fw_scratch_done(st_local("scratch"))
    if `rc' exit `rc'
    if "`publish'" != "" return add
    else return local slug `"`slug'"'
    return local file `"`savepath'"'
    return local root `"`fw_tree_root'"'
    return local base `"`fw_tree_base'"'
    return local method `"`fw_tree_method'"'
    return scalar nodes = `fw_tree_nodes'
end
