*! fw_project: find the Framework project and set path globals
*! Part of the framework package
program define fw_project, rclass
    version 14
    syntax [, ROOT(string) Quietly]
    _fw_init
    if `"`root'"' == "" local root `"`c(pwd)'"'
    mata: fw_project_load(st_local("root"), "`quietly'" != "")
    return local root `"$fw_root"'
    return local name `"$fw_project_name"'
    return local folders `"$fw_dir_list"'
    return local conflicts `"$fw_settings_conflicts"'
end
