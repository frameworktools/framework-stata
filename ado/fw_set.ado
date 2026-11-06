*! fw_set: set or show Framework for Stata options
*! Part of the framework package
program define fw_set
    version 14
    _fw_init
    gettoken key value : 0
    local key = lower(`"`key'"')
    local value = trim(`"`value'"')
    if `"`key'"' == "" {
        mata: st_local("b", fw_conf_get("backend"))
        mata: st_local("p", fw_conf_get("fw_path"))
        mata: st_local("f", fw_config_dir() + "/stata.conf")
        display as text "Framework for Stata options (" as result `"`f'"' as text ")"
        display as text "  backend  " as result cond(`"`b'"' == "", "auto (default)", `"`b'"')
        display as text "  fw_path  " as result cond(`"`p'"' == "", "(search the PATH)", `"`p'"')
        if `"`p'"' != "" {
            capture confirm file `"`p'"'
            if _rc display as text "  That file no longer exists. Framework searches the PATH until you run fw_set fw_path again."
        }
        if `"$FW_BACKEND"' != "" {
            display as text "  The global FW_BACKEND overrides the backend for this session: " as result `"$FW_BACKEND"'
        }
        exit
    }
    if `"`key'"' == "backend" {
        local value = lower(`"`value'"')
        if !inlist(`"`value'"', "auto", "core", "cli", "python") {
            display as error "Use: fw_set backend auto|core|cli|python"
            exit 198
        }
        if `"`value'"' == "python" & c(stata_version) < 16 {
            display as error "The Python backend needs Stata 16 or newer. This is Stata `c(stata_version)'."
            exit 198
        }
        local store = cond(`"`value'"' == "auto", "", `"`value'"')
        mata: fw_conf_set("backend", st_local("store"))
        display as text "Backend: " as result `"`value'"'
        exit
    }
    if `"`key'"' == "fw_path" {
        gettoken value : value
        if inlist(lower(`"`value'"'), "", "clear") {
            mata: fw_conf_set("fw_path", "")
            display as text "fw_path cleared. Framework searches the PATH for fw."
            exit
        }
        mata: st_local("value", fw_abs(st_local("value")))
        capture confirm file `"`value'"'
        if _rc {
            display as error `"No file at `value'."'
            exit 601
        }
        mata: fw_conf_set("fw_path", st_local("value"))
        display as text "fw_path: " as result `"`value'"'
        exit
    }
    display as error `"Unknown option "`key'". Use fw_set backend or fw_set fw_path."'
    exit 198
end
