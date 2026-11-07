*! fw_publish: publish a file or the current estimation results
*! Part of the framework package
program define fw_publish, rclass
    version 14
    syntax [anything(name=file id="file")] [, ESTimates SLUG(string) TItle(string) ///
        DESCription(string) TO(string) VISibility(string) PRIVate INCLUDEPRIVate KIND(string) ///
        Level(cilevel) SAVing(string asis)]
    _fw_need_project
    gettoken file rest : file
    if `"`rest'"' != "" {
        display as error "fw_publish takes one file or folder at a time. To publish several files as one artifact, give their folder or a wildcard such as outputs/figures/*.png."
        exit 198
    }
    if "`estimates'" != "" & `"`file'"' != "" {
        display as error "Give a file or the estimates option, not both."
        exit 198
    }
    if "`estimates'" == "" & `"`file'"' == "" {
        display as error "Give a file to publish, or use fw_publish, estimates for the current estimation results."
        exit 198
    }
    local visibility = lower(`"`visibility'"')
    if !inlist(`"`visibility'"', "", "public", "unlisted", "private") {
        display as error "visibility() must be public, unlisted, or private."
        exit 198
    }
    * private is short for visibility(private).
    if "`private'" != "" {
        if !inlist(`"`visibility'"', "", "private") {
            display as error "The private option means visibility(private). It cannot go with visibility(`visibility')."
            exit 198
        }
        local visibility private
    }
    if `"`saving'"' != "" & "`estimates'" == "" {
        display as error "saving() goes with the estimates option."
        exit 198
    }

    local fw_isdir 0
    local fw_wild 0
    mata: fw__publish_scratch = fw_scratch()
    mata: st_local("scratch", fw__publish_scratch)
    capture noisily {
        * Estimation results become a model.json file first.
        if "`estimates'" != "" {
            local cmd `"`e(cmd)'"'
            local dep : word 1 of `e(depvar)'
            * stcox stores e(cmd) cox and e(cmd2) stcox.
            if "`e(cmd2)'" == "stcox" local cmd stcox
            if "`cmd'" == "stcox" local dep "_t"
            local stem = cond("`dep'" != "", "`cmd'-`dep'", "`cmd'")
            if "`stem'" == "" local stem model
            local file `"`scratch'/`stem'.json"'
            mata: fw_writefile(st_local("file"), fw_model_json(`level'))
            if !`fw_known' {
                display as text "Note: Framework has no specific mapping for `cmd'. It published a generic coefficient table."
            }
            if `"`saving'"' != "" {
                gettoken savepath saveopts : saving, parse(",")
                local saveopts : subinstr local saveopts "," ""
                local saveopts = trim(`"`saveopts'"')
                mata: st_local("savepath", fw_abs(st_local("savepath")))
                capture confirm file `"`savepath'"'
                if !_rc & "`saveopts'" != "replace" {
                    display as error `"`savepath' already exists. Use saving("`savepath'", replace)."'
                    exit 602
                }
                copy `"`file'"' `"`savepath'"', replace
                display as text `"Saved the model to `savepath'"'
            }
            * The scratch model file is removed on return; r(file) names the saved copy.
            local rfile `"`savepath'"'
            if `"`kind'"' == "" local kind model
            if `"`title'"' == "" local title = cond("`dep'" != "", "`cmd': `dep'", "`cmd'")
        }
        else {
            * A folder or a wildcard publishes as one artifact, as publish_dir() does.
            mata: fw_publish_select(st_local("file"))
            if !`fw_isdir' {
                capture confirm file `"`file'"'
                if _rc {
                    display as error `"File not found: `file'"'
                    exit 601
                }
            }
            local rfile `"`file'"'
        }

        * The private-path rule, shared with R, Python, and fw. Estimates
        * go through a scratch file, so the rule checks the file the data
        * in memory came from: the last fw_use or fw_save, or c(filename)
        * when a plain use or save has loaded another file since.
        local datasrc
        if "`estimates'" != "" {
            local datasrc `"`c(filename)'"'
            if `"$fw__data_source"' != "" & `"`c(filename)'"' == `"$fw__data_filename"' local datasrc `"$fw__data_source"'
        }
        local include_private = ("`includeprivate'" != "")
        if !`include_private' {
            mata: fw__flagged = fw_private_flagged(fw_publish_files(st_local("file"), `fw_isdir') \ ///
                (st_local("datasrc") != "" ? fw_abs(st_local("datasrc")) : J(0, 1, "")))
            mata: st_local("nflag", strofreal(rows(fw__flagged)))
            if `nflag' {
                if "`estimates'" != "" {
                    display as text "Warning: these estimation results come from data in a file with 'private' in its path:"
                }
                else display as text "Warning: `nflag' file(s) to publish have 'private' in their path:"
                mata: printf("{txt}  %s\n", invtokens(fw__flagged', char(10) + "  "))
                if c(mode) == "batch" {
                    display as error "Not publishing files with 'private' in their path without confirmation."
                    display as error "Review them, then add the includeprivate option to publish them."
                    exit 198
                }
                display as text "Publish them anyway? Type y and press Enter: " _request(_fw_answer)
                if !inlist(lower(trim(`"$_fw_answer"')), "y", "yes") {
                    macro drop _fw_answer
                    display as error "Cancelled. Nothing was published."
                    exit 1
                }
                macro drop _fw_answer
                local include_private 1
            }
        }

        mata: fw_destination(st_local("to"))
        _fw_backend, driver(`fw_driver')
        local backend `"`r(backend)'"'
        local fwexe `"`r(fw)'"'
        if "`fw_driver'" == "folder" & "`backend'" == "core" {
            if `"`fw_dest_path'"' == "" {
                if "`fw_dest'" == "folder" {
                    display as error "to(folder) needs a folder. Name a folder destination with a path under publish.destinations, then use its name in to()."
                }
                else display as error "The folder destination `fw_dest' needs a path in publish.destinations."
                exit 198
            }
            if `"`visibility'"' != "" & `"`visibility'"' != `"`fw_dest_visibility'"' {
                if `"`fw_dest_visibility'"' == "" {
                    display as error "The folder destination `fw_dest' sets no visibility. Add visibility: `visibility' to it, or leave out visibility()."
                }
                else display as error "Folder visibility must match the destination's configured visibility (`fw_dest_visibility')."
                exit 198
            }
            local bundle `"`scratch'/bundle"'
            if `fw_isdir' {
                mata: fw__manifest = fw_bundle_build_dir(fw__srcdir, fw__selected, st_local("bundle"), st_local("slug"), ///
                    st_local("title"), st_local("description"), st_local("kind"), st_local("scratch"))
            }
            else {
                mata: fw__manifest = fw_bundle_build(st_local("file"), st_local("bundle"), st_local("slug"), ///
                    st_local("title"), st_local("description"), st_local("kind"), st_local("scratch"))
            }
            mata: fw_folder_deliver(st_local("bundle"), st_local("fw_dest_path"), st_local("fw_dest_url"), st_local("fw_slug"))
            mata: fw_track_external(st_global("fw_root"), st_local("bundle"), fw__manifest, "folder", ///
                st_local("visibility") != "" ? st_local("visibility") : st_local("fw_dest_visibility"))
        }
        else if "`fw_driver'" == "cloud" & "`backend'" == "core" {
            if `fw_isdir' {
                * Upload a copy of the selected files, with a file list when
                * the folder has no page of its own.
                mata: st_local("file", st_local("scratch") + "/stage/" + fw_basename(fw__srcdir))
                mata: fw_stage_selected(fw__srcdir, fw__selected, st_local("file"))
                mata: st_local("pages", strofreal(rows(dir(st_local("file"), "files", "*.htm*", 0))))
                if `pages' == 0 mata: fw_dir_index(st_local("file"))
            }
            mata: fw_cloud_publish(st_global("fw_root"), st_local("file"), st_local("slug"), st_local("title"), ///
                st_local("description"), st_local("kind"), st_local("visibility"))
        }
        else {
            * fw and framework-py publish folders. A wildcard sends a copy of
            * the matching files, and fw gets a file list when the folder has
            * no index.html, as the folder driver writes. The files were
            * checked above, and the copy sits in a temporary folder, so the
            * backend need not ask again.
            if `fw_isdir' & (`fw_wild' | "`backend'" == "cli") {
                mata: st_local("file", st_local("scratch") + "/stage/" + fw_basename(fw__srcdir))
                mata: fw_stage_selected(fw__srcdir, fw__selected, st_local("file"))
                if "`backend'" == "cli" mata: fw_dir_index(st_local("file"))
            }
            if `fw_isdir' local include_private 1
            mata: st_local("fw_slug", fw_default_slug(st_local("file"), st_local("slug")))
            local dest `"`to'"'
            if "`backend'" == "cli" {
                mata: fw_cli_publish(st_local("fwexe"), st_local("file"), st_local("dest"), st_local("slug"), ///
                    st_local("title"), st_local("description"), st_local("kind"), st_local("visibility"), ///
                    `include_private', st_global("fw_root"))
            }
            else {
                capture findfile fw_bridge.py
                if _rc {
                    display as error "The framework package is incomplete: fw_bridge.py is missing. Reinstall the package."
                    exit 601
                }
                local bridge `"`r(fn)'"'
                mata: fw_bridge_args(st_local("scratch") + "/args.json", st_local("file"), st_local("dest"), ///
                    st_local("slug"), st_local("title"), st_local("description"), st_local("kind"), ///
                    st_local("visibility"), `include_private')
                python script `"`bridge'"', args(publish `"`scratch'/args.json"' `"`scratch'/result.json"')
                mata: fw_bridge_result(st_local("scratch") + "/result.json")
            }
        }
    }
    local rc = _rc
    mata: fw_scratch_done(st_local("scratch"))
    if `rc' exit `rc'

    local where `"`fw_url'"'
    if `"`where'"' == "" local where `"`fw_location'"'
    local vtext = cond("`fw_version'" != "", " (version `fw_version')", "")
    display as text `"Published to `fw_dest'`vtext': "' _c
    if regexm(`"`where'"', "^https?://") display as result `"{browse "`where'"}"'
    else display as result `"`where'"'
    if `"`fw_notice'"' != "" display as text `"`fw_notice'"'
    return local url `"`fw_url'"'
    return local location `"`fw_location'"'
    return local version `"`fw_version'"'
    return local version_url `"`fw_version_url'"'
    return local destination `"`fw_dest'"'
    return local driver `"`fw_driver'"'
    return local backend `"`backend'"'
    return local slug `"`fw_slug'"'
    return local file `"`rfile'"'
    local nfiles 1
    if `fw_isdir' mata: st_local("nfiles", strofreal(rows(fw__selected)))
    return scalar files = `nfiles'
end
