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
        display as error "fw_publish takes one file at a time."
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
            mata: st_local("file", fw_abs(st_local("file")))
            capture confirm file `"`file'"'
            if _rc {
                display as error `"File not found: `file'"'
                exit 601
            }
            local rfile `"`file'"'
        }

        * The private-path rule, shared with R, Python, and fw.
        local include_private = ("`includeprivate'" != "")
        if !`include_private' {
            mata: st_local("nflag", strofreal(rows(fw_private_flagged(fw_publish_sources(st_local("file"))))))
            if `nflag' {
                mata: st_local("flagged", invtokens(fw_private_flagged(fw_publish_sources(st_local("file")))', char(10)))
                display as text "Warning: `nflag' file(s) to publish have 'private' in their path:"
                mata: printf("{txt}  %s\n", invtokens(fw_private_flagged(fw_publish_sources(st_local("file")))', char(10) + "  "))
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
            mata: fw__manifest = fw_bundle_build(st_local("file"), st_local("bundle"), st_local("slug"), ///
                st_local("title"), st_local("description"), st_local("kind"), st_local("scratch"))
            mata: fw_folder_deliver(st_local("bundle"), st_local("fw_dest_path"), st_local("fw_dest_url"), st_local("fw_slug"))
            mata: fw_track_external(st_global("fw_root"), st_local("bundle"), fw__manifest, "folder", ///
                st_local("visibility") != "" ? st_local("visibility") : st_local("fw_dest_visibility"))
        }
        else if "`fw_driver'" == "cloud" & "`backend'" == "core" {
            mata: fw_cloud_publish(st_global("fw_root"), st_local("file"), st_local("slug"), st_local("title"), ///
                st_local("description"), st_local("kind"), st_local("visibility"))
        }
        else if "`backend'" == "cli" {
            mata: st_local("fw_slug", fw_default_slug(st_local("file"), st_local("slug")))
            local dest `"`to'"'
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
            mata: st_local("fw_slug", fw_default_slug(st_local("file"), st_local("slug")))
            local dest `"`to'"'
            mata: fw_bridge_args(st_local("scratch") + "/args.json", st_local("file"), st_local("dest"), ///
                st_local("slug"), st_local("title"), st_local("description"), st_local("kind"), ///
                st_local("visibility"), `include_private')
            python script `"`bridge'"', args(publish `"`scratch'/args.json"' `"`scratch'/result.json"')
            mata: fw_bridge_result(st_local("scratch") + "/result.json")
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
end
