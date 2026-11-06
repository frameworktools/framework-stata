*! _fw_init: load the Framework for Stata Mata functions once per session
*! Part of the framework package. Not for direct use.
program define _fw_init
    version 14
    capture mata: fw_loaded()
    if !_rc exit
    capture mata: mata drop fw_*() fw__*()
    foreach f in fw_core fw_data fw_estimates fw_publish fw_cloud {
        capture findfile `f'.mata
        if _rc {
            display as error "The framework package is incomplete: `f'.mata is missing."
            display as error `"Reinstall it with: net install framework, from("<folder or URL>") replace"'
            exit 601
        }
        quietly run `"`r(fn)'"'
    }
end
