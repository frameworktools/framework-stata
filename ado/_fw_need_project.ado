*! _fw_need_project: load the project when no project is loaded yet
*! Part of the framework package. Not for direct use.
program define _fw_need_project
    version 14
    _fw_init
    capture mata: fw_S()
    if _rc {
        fw_project, quietly
    }
end
