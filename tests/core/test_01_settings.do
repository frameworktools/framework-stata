* Project discovery, the YAML reader, split files, environments, and globals.

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/settings"'
mkdir `"`root'/notebooks"'
mkdir `"`root'/notebooks/deep"'
copy `"$FW_TEST_REPO/tests/fixtures/project_yaml/settings.yml"' `"`root'/settings.yml"'
copy `"$FW_TEST_REPO/tests/fixtures/project_yaml/settings/data.yml"' `"`root'/settings/data.yml"'

t_begin settings: find the root from a nested folder
capture noisily {
    quietly cd `"`root'/notebooks/deep"'
    fw_project, quietly
    t_eq `"`r(root)'"' `"`root'"'
    t_eq `"$fw_root"' `"`root'"'
}
local rc = _rc
quietly cd `"$FW_TEST_REPO"'
t_end `rc'

t_begin settings: directory globals are absolute
capture noisily {
    t_eq `"$fw_inputs_raw"' `"`root'/inputs/raw"'
    t_eq `"$fw_inputs_final"' `"`root'/inputs/final"'
    t_eq `"$fw_outputs_figures"' `"`root'/outputs/figures"'
    t_eq `"$fw_notebooks"' `"`root'/notebooks"'
    t_eq `"$fw_data"' `"`root'/inputs/final"'
    t_eq `"$fw_project_name"' "example-study"
}
t_end `=_rc'

t_begin settings: split file and nested data catalog
capture noisily {
    mata: S = fw_S()
    mata: st_local("p", fw_setting(S, "data.inputs.raw.survey.path"))
    mata: st_local("l", fw_setting(S, "data.inputs.raw.survey.locked"))
    t_eq `"`p'"' "inputs/raw/survey.csv"
    t_eq `"`l'"' "true"
}
t_end `=_rc'

t_begin settings: flow lists, block scalars, lists of maps
capture noisily {
    mata: st_local("a", fw_setting(S, "options.tags.0"))
    mata: st_local("b", fw_setting(S, "options.tags.1"))
    mata: st_local("n", fw_setting(S, "options.tags.#"))
    t_eq `"`a'"' "alpha"
    t_eq `"`b'"' "beta, gamma"
    t_eq `"`n'"' "2"
    mata: st_local("note", fw_setting(S, "note"))
    t_eq `"`note'"' "line one`=char(10)'line two`=char(10)'"
    mata: st_local("m", fw_setting(S, "list_of_maps.1.name") + fw_setting(S, "list_of_maps.1.value"))
    t_eq `"`m'"' "b2"
    mata: st_local("d", fw_setting(S, "publish.destinations.lab.driver"))
    t_eq `"`d'"' "folder"
}
t_end `=_rc'

t_begin settings: the active environment overrides default
capture noisily {
    * Stata cannot set environment variables; test the selection function directly.
    mata: R = fw__select_env(fw_yaml_read(st_local("root") + "/settings.yml"), "staging")
    mata: st_local("r", fw_setting(R, "directories.inputs_raw"))
    mata: st_local("f", fw_setting(R, "directories.inputs_final"))
    t_eq `"`r'"' "inputs/raw-staging"
    t_eq `"`f'"' "inputs/final"
}
t_end `=_rc'

t_begin settings: fw-generated settings.do supplies folders
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    copy `"$FW_TEST_REPO/tests/fixtures/project_do/settings.do"' `"`s'/settings.do"'
    fw_project, root(`"`s'"') quietly
    t_eq `"$fw_inputs_raw"' `"`s'/inputs/raw"'
    t_eq `"$fw_do"' `"`s'/do"'
    * Globals from the previous project are cleared.
    t_eq `"$fw_notebooks"' ""
    t_eq `"$fw_outputs_figures"' `"`s'/outputs/figures"'
}
t_end `=_rc'

t_begin settings: no project gives a clear error
capture noisily {
    t_tmpdir
    capture fw_project, root(`"`r(dir)'"') quietly
    assert _rc == 601
}
t_end `=_rc'

t_begin json: parse nested values, escapes, and numbers
capture noisily {
    mata: J = fw_json_parse(`"{"a": {"b": [1, 2.5, "x\"y"], "c": null}, "u": "café", "t": true}"')
    mata: st_local("v", fw_get(J, "a.b.2") + "|" + fw_get(J, "a.b.#") + "|" + fw_get(J, "a.b.1") + "|" + fw_get(J, "u") + "|" + fw_get(J, "t") + "|" + fw_get(J, "a.c"))
    t_eq `"`v'"' `"x"y|3|2.5|café|true|"'
}
t_end `=_rc'

t_begin json: numbers and strings round-trip
capture noisily {
    mata: st_local("v", fw_json_num(0.5) + " " + fw_json_num(-0.25) + " " + fw_json_num(3) + " " + fw_json_num(.))
    t_eq `"`v'"' "0.5 -0.25 3 null"
    mata: x = (1e-7, 1/3, -123456.789, 2^60)
    mata: for (i = 1; i <= 4; i++) assert(strtoreal(fw_json_num(x[i])) == x[i])
    mata: J = fw_json_parse("[" + fw_json_num(1e-7) + "," + fw_json_str("a" + char(10) + char(34) + char(92)) + "]")
    mata: assert(fw_get(J, "1") == "a" + char(10) + char(34) + char(92))
}
t_end `=_rc'

t_begin paths: the private-path rule
capture noisily {
    mata: st_local("v", strofreal(fw_is_private("/data/Private/x.csv")) + strofreal(fw_is_private("/private/tmp/x.csv")) + strofreal(fw_is_private("/private/tmp/private-x.csv")) + strofreal(fw_is_private("/data/public/x.csv")))
    t_eq "`v'" "1010"
}
t_end `=_rc'

t_begin paths: slugs match R and Python
capture noisily {
    mata: st_local("v", fw_slug("Model: Price ~ MPG (2026)!"))
    t_eq "`v'" "model-price-mpg-2026"
}
t_end `=_rc'

t_begin paths: helpers leave their arguments unchanged
capture noisily {
    * Mata passes arguments by reference. A helper that changed its
    * argument broke the project-root fallback for relative paths.
    mata: p = "outputs/../outputs/x.csv"
    mata: q = fw_abs(p, "/base")
    mata: assert(p == "outputs/../outputs/x.csv")
    mata: assert(q == "/base/outputs/x.csv")
    mata: p = "a" + char(92) + "b/"
    mata: q = fw_norm(p) + fw_dirname(p) + fw_basename(p)
    mata: assert(p == "a" + char(92) + "b/")
    mata: p = "/r/x/y"
    mata: r = "/r/"
    mata: q = fw_relpath(p, r)
    mata: assert(p == "/r/x/y" & r == "/r/" & q == "x/y")
    mata: p = "My Model"
    mata: q = fw_slug(p) + fw_json_str(p)
    mata: assert(p == "My Model")
}
t_end `=_rc'

t_begin settings: tab indentation stops with a clear error
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    t_write `"`s'/settings.yml"' "default:" "`=char(9)'directories:" "`=char(9)'`=char(9)'inputs_raw: inputs/raw"
    t_log_begin
    capture noisily fw_project, root(`"`s'"') quietly
    local rc = _rc
    t_log_end
    assert `rc' == 198
    t_log_has "line 2: a tab is used for indentation"
    * A tab after spaces is caught too, and tabs on blank lines are fine.
    t_write `"`s'/settings.yml"' "default:" "`=char(9)'" "  directories:" "  `=char(9)'inputs_raw: inputs/raw"
    capture fw_project, root(`"`s'"') quietly
    assert _rc == 198
    t_write `"`s'/settings.yml"' "default:" "`=char(9)'" "  directories:" "    inputs_raw: inputs/raw"
    fw_project, root(`"`s'"') quietly
    t_eq `"$fw_inputs_raw"' `"`s'/inputs/raw"'
}
t_end `=_rc'

t_begin settings: settings.do lines with braces and absolute paths
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    * Built in Mata: a do-file cannot hold a literal dollar sign or backtick here.
    mata: d = char(36); o = char(96) + char(34); c = char(34) + char(39); n = char(10)
    mata: fw_writefile(st_local("s") + "/settings.do", ///
        "global inputs_raw " + o + d + "root/inputs/raw" + c + n + ///
        "global inputs_final " + char(34) + d + "{root}/inputs/final" + char(34) + n + ///
        "global outputs_tables " + char(34) + st_local("s") + "/outputs/tables" + char(34) + n + ///
        "global other " + o + d + "elsewhere/x" + c + n)
    fw_project, root(`"`s'"') quietly
    t_eq `"$fw_inputs_raw"' `"`s'/inputs/raw"'
    t_eq `"$fw_inputs_final"' `"`s'/inputs/final"'
    t_eq `"$fw_outputs_tables"' `"`s'/outputs/tables"'
    t_eq `"$fw_other"' ""
}
t_end `=_rc'

t_begin settings: a key too long for a global is reported, not listed
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    t_write `"`s'/settings.yml"' "directories:" "  inputs_raw: inputs/raw" "  a_folder_key_that_is_far_too_long_for_stata: x"
    t_log_begin
    fw_project, root(`"`s'"')
    local folders `"`r(folders)'"'
    t_log_end
    t_eq `"`folders'"' "inputs_raw"
    t_log_has "Skipped a_folder_key_that_is_far_too_long_for_stata"
    * The old summary printed the key's would-be global run into its path.
    t_log_lacks "for_statax"
}
t_end `=_rc'

t_begin settings: a long folder global keeps a space before its path
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    t_write `"`s'/settings.yml"' "directories:" "  inputs_private_intermediate: inputs/private/intermediate" "  inputs_raw: inputs/raw"
    t_log_begin
    fw_project, root(`"`s'"')
    t_log_end
    t_log_has "\$fw_inputs_private_intermediate inputs/private/intermediate"
    t_log_lacks "intermediateinputs"
}
t_end `=_rc'

t_begin settings: project_name names the project, as in R and Python
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    t_write `"`s'/settings.yml"' "default:" "  project_name: study-stata" "  project:" "    name: older-key" "  directories:" "    inputs_raw: inputs/raw"
    fw_project, root(`"`s'"') quietly
    t_eq `"`r(name)'"' "study-stata"
    t_eq `"$fw_project_name"' "study-stata"
    * project.name still works, and the folder name is the last resort.
    t_write `"`s'/settings.yml"' "default:" "  project:" "    name: older-key"
    fw_project, root(`"`s'"') quietly
    t_eq `"`r(name)'"' "older-key"
    t_write `"`s'/settings.yml"' "default:" "  directories:" "    inputs_raw: inputs/raw"
    fw_project, root(`"`s'"') quietly
    mata: st_local("base", fw_basename(st_local("s")))
    t_eq `"`r(name)'"' `"`base'"'
}
t_end `=_rc'

t_begin settings: settings.yml and settings.do together, as fw writes a Stata project
capture noisily {
    t_tmpdir
    local s `"`r(dir)'"'
    * settings.do holds the folders, settings.yml everything shared with R and Python.
    mata: d = char(36); o = char(96) + char(34); c = char(34) + char(39); n = char(10)
    mata: fw_writefile(st_local("s") + "/settings.do", ///
        "global root " + o + char(96) + "c(pwd)'" + c + n + ///
        "global inputs_private_raw " + o + d + "root/inputs/private/raw" + c + n + ///
        "global inputs_public_final " + o + d + "root/inputs/public/final" + c + n + ///
        "global outputs_private_tables " + o + d + "root/outputs/private/tables" + c + n + ///
        "global outputs_public_tables " + o + d + "root/outputs/public/tables" + c + n + ///
        "global logs " + o + d + "root/logs" + c + n)
    t_write `"`s'/settings.yml"' ///
        "default:" ///
        "  project_name: both-files" ///
        "  security:" ///
        "    sensitive: true" ///
        "  directories:" ///
        "    logs: run-logs" ///
        "  data:" ///
        "    inputs:" ///
        "      public:" ///
        "        cars:" ///
        "          path: inputs/public/final/cars.csv" ///
        "  publish:" ///
        "    default: local" ///
        "    destinations:" ///
        "      local:" ///
        "        driver: folder" ///
        "        path: published" ///
        "        visibility: public"
    quietly cd `"`s'"'
    t_log_begin
    fw_project
    local name `"`r(name)'"'
    local conflicts `"`r(conflicts)'"'
    t_log_end
    t_eq `"`name'"' "both-files"
    t_eq `"$fw_inputs_private_raw"' `"`s'/inputs/private/raw"'
    t_eq `"$fw_outputs_public_tables"' `"`s'/outputs/public/tables"'
    * A folder both files set: settings.yml wins, and fw_project says so.
    t_eq `"$fw_logs"' `"`s'/run-logs"'
    t_eq `"`conflicts'"' "logs"
    t_log_has "settings.yml and settings.do set the folder logs differently. Using settings.yml: run-logs"
    * The catalog, fw_table's private and public split, and publish
    * destinations come from settings.yml; the folders from settings.do.
    sysuse auto, clear
    keep make price
    fw_save "inputs/public/final/cars.csv", replace
    fw_use inputs.public.cars, clear
    assert c(N) == 74
    fw_table cars
    t_eq `"`r(path)'"' `"`s'/outputs/private/tables/cars.csv"'
    fw_table cars, public
    fw_publish `"`r(path)'"'
    t_eq `"`r(destination)'"' "local"
    confirm file `"`s'/published/cars/cars.csv"'
}
local rc = _rc
quietly cd `"$FW_TEST_REPO"'
t_end `rc'
