*! fw_login: connect this computer to Framework Cloud
*! Part of the framework package
program define fw_login, rclass
    version 14
    syntax [, URL(string) NOBrowser]
    _fw_init
    mata: fw_login_run(st_local("url"), "`nobrowser'" != "")
    return local account `"`fw_account'"'
    return local stored `"`fw_stored'"'
end
