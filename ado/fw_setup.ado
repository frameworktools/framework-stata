*! fw_setup: check Stata, the backends, and the Cloud connection
*! Part of the framework package
program define fw_setup, rclass
    version 14
    syntax [, NOPython NONetwork URL(string)]
    _fw_init
    local steps 0
    local ok "{res}ok{txt}"
    local no "{err}missing{txt}"

    mata: st_local("ver", fw_version())
    display as text _n "{bf:Framework for Stata} " as result "`ver'"
    mata: st_local("pkgdir", fw_dirname(fw_norm(findfile("fw_core.mata"))))
    display as text "  installed in    " as result `"`pkgdir'"'
    display as text "  Stata           " as result "`c(stata_version)' (`c(edition_real)', `c(os)')"

    * Project
    display as text _n "{bf:Project}"
    mata: st_local("root", fw_find_root(pwd()))
    if `"`root'"' == "" {
        display as text "  No project at or above " as result `"`c(pwd)'"'
        display as text "  {it:cd} to a Framework project folder before running fw_project."
    }
    else {
        capture noisily fw_project, root(`"`root'"') quietly
        display as text "  root            " as result `"`root'"'
        display as text "  folders         " as result `"$fw_dir_list"'
    }

    * Tools that ship with the operating system
    display as text _n "{bf:System tools}"
    mata: fw__setup_tools()
    if "`have_curl'" == "0" {
        local ++steps
        local step`steps' "Install curl. It ships with macOS, Linux, and Windows 10 or later. Framework uses it for Cloud publishing and login."
    }
    if "`have_sha'" == "0" {
        local ++steps
        local step`steps' "Install a SHA-256 tool (sha256sum on Linux). Without one, fw_save records the datasignature only."
    }

    * Framework Cloud
    display as text _n "{bf:Framework Cloud}"
    mata: st_local("server", fw_cloud_url("", st_local("url")))
    mata: st_local("source", fw__setup_token(st_local("server")))
    display as text "  server          " as result `"`server'"'
    if "`source'" == "none" {
        display as text "  login           " as text "not connected"
        local ++steps
        local step`steps' "Connect this computer to Framework Cloud (optional): fw_login"
    }
    else {
        display as text "  login           " as result "token from `source'"
        if "`nonetwork'" == "" & "`have_curl'" == "1" {
            mata: fw__setup_me(st_local("server"))
        }
    }
    if `"`root'"' != "" {
        mata: st_local("ptok", strofreal(fw_env("FW_PROJECT_TOKEN") != "" | fw_dotenv(st_local("root"), "FW_PROJECT_TOKEN") != ""))
        display as text "  project token   " as result cond(`ptok', "set", "not set") as text cond(`ptok', "", " (needed to publish this project to Cloud)")
    }

    * fw
    display as text _n "{bf:CLI backend (fw)}"
    mata: fw__setup_fw()
    if `"`fwstale'"' != "" {
        display as text "  fw_path         " as error `"`fwstale'"' as text " no longer exists. Framework searched the PATH instead."
        local ++steps
        local step`steps' `"Update or clear the stale fw_path: fw_set fw_path <path to fw>, or fw_set fw_path clear"'
    }
    if `"`fwexe'"' == "" {
        display as text "  fw              " as text "not found"
        display as text "  Install it from {browse https://framework.pub/docs/cli}, or point to it with fw_set fw_path <path>."
    }

    * Python
    display as text _n "{bf:Python backend (framework-py)}"
    if c(stata_version) < 16 {
        display as text "  Needs Stata 16 or newer. Framework for Stata works without it."
    }
    else if "`nopython'" != "" {
        display as text "  Skipped (nopython)."
    }
    else {
        display as text "  {it:Checking starts Stata's Python for this session. Use fw_setup, nopython to skip.}"
        _fw_python
        local pyok = r(ok)
        if `"`r(exec)'"' != "" display as text "  python          " as result `"`r(exec)'"'
        else display as text "  python          " as text "not configured"
        if `pyok' {
            display as text "  framework-py    " as result "`r(version)'"
        }
        else {
            display as text "  framework-py    " as text "not available"
            display as text `"  `r(why)'"'
        }
    }

    * Backend
    display as text _n "{bf:Backend}"
    local pref `"$FW_BACKEND"'
    if `"`pref'"' == "" mata: st_local("pref", fw_conf_get("backend"))
    if `"`pref'"' == "" local pref auto
    display as text "  setting         " as result `"`pref'"' as text cond(`"$FW_BACKEND"' != "", " (from the FW_BACKEND global)", "")
    local pref = lower(`"`pref'"')
    if "`pref'" == "cli" {
        display as text "  Stata handles projects, data, checksums, and login. Every publish goes through fw."
        if `"`fwexe'"' == "" display as error "  fw was not found, so fw_publish stops until it is installed."
    }
    else if "`pref'" == "python" {
        display as text "  Stata handles projects, data, checksums, and login. Every publish goes through framework-py."
        if "`pyok'" != "1" display as text "  framework-py was not checked or is not available. fw_publish stops until it is."
    }
    else if "`pref'" == "core" {
        display as text "  Stata handles projects, data, checksums, folder and Cloud publishing, and login itself."
        display as text "  GitHub and S3 publishing are off."
    }
    else {
        display as text "  Stata handles projects, data, checksums, folder and Cloud publishing, and login itself."
        if `"`fwexe'"' != "" display as text "  GitHub and S3 publishing use: " as result "fw"
        else if "`pyok'" == "1" display as text "  GitHub and S3 publishing use: " as result "framework-py"
        else {
            display as text "  GitHub and S3 publishing need fw or framework-py."
            local ++steps
            local step`steps' "For GitHub Pages and S3 publishing (optional): install fw, or framework-py in a Python 3.11 or newer. See the CLI and Python sections above."
        }
    }

    display as text _n "{bf:Next steps}"
    if `steps' == 0 display as text "  None. Framework for Stata is ready."
    forvalues i = 1/`steps' {
        display as text "  `i'. `step`i''"
    }
    return scalar steps = `steps'
end
