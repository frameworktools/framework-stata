*! fw_logout: remove this computer's Framework Cloud token
*! Part of the framework package
program define fw_logout
    version 14
    syntax [, URL(string)]
    _fw_init
    mata: fw_logout_run(st_local("url"))
end
