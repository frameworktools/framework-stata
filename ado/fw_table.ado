*! fw_table: save the data in memory or a matrix as a table in the tables folder
*! Part of the framework package
program define fw_table, rclass
    version 14
    gettoken name 0 : 0, parse(" ,")
    if `"`name'"' == "" | `"`name'"' == "," {
        display as error "Give a name for the table, such as fw_table summary or fw_table meeting/summary."
        exit 198
    }
    syntax [varlist(default=none)] [if] [in] [, MATrix(name) HEADers(string asis) VARNames ///
        NOLabel FORmat(string) PUBlic NOREPlace REPLace NA(string)]
    _fw_need_project
    if "`matrix'" != "" & ("`varlist'" != "" | `"`if'"' != "" | `"`in'"' != "") {
        display as error "Give a matrix() or a varlist with if and in, not both."
        exit 198
    }
    if "`matrix'" == "" & c(k) == 0 {
        display as error "There is no data in memory to save. Load data, or give a matrix()."
        exit 2000
    }
    if `"`na'"' == "" local na NA

    * Formats: from the name's extension, else format(), else csv.
    mata: fw_output_target("tables", st_local("name"), "`public'" != "", ("csv", "xlsx"))
    local format = lower(trim(`"`format'"'))
    if "`fw_ext'" != "" {
        if "`format'" != "" & "`format'" != "`fw_ext'" {
            display as error "The name ends in .`fw_ext', but format() is `format'."
            exit 198
        }
        local format `fw_ext'
    }
    if "`format'" == "" local format csv
    local format : list uniq format
    foreach f of local format {
        if !inlist("`f'", "csv", "xlsx") {
            display as error "format() takes csv, xlsx, or both (got `f')."
            exit 198
        }
        if "`noreplace'" != "" {
            capture confirm file `"`fw_stem'.`f'"'
            if !_rc {
                display as error `"`fw_stem'.`f' already exists. Leave out noreplace to overwrite it."'
                exit 602
            }
        }
    }

    * A public table from data that came from a private file gets a warning.
    if "`public'" != "" & "`matrix'" == "" {
        local datasrc `"`c(filename)'"'
        if `"$fw__data_source"' != "" & `"`c(filename)'"' == `"$fw__data_filename"' local datasrc `"$fw__data_source"'
        if `"`datasrc'"' != "" {
            mata: st_local("priv", strofreal(fw_is_private(st_local("datasrc"))))
            if `priv' {
                display as text `"Warning: this public table comes from data in a file with 'private' in its path:"'
                display as text `"  `datasrc'"'
                display as text "Check that it holds only results that may be shared."
            }
        }
    }

    mata: fw__given = fw_words(st_local("headers"))
    local N 0
    local K 0
    local paths
    preserve
    capture noisily {
        if "`matrix'" != "" {
            clear
            mata: fw__defaults = fw_matrix_data(st_local("matrix"))
        }
        else {
            mata: fw__defaults = J(1, 0, "")
            if "`varlist'" == "" unab varlist : _all
            marksample touse, novarlist strok
            quietly keep if `touse'
            keep `varlist'
            order `varlist'
        }
        mata: fw__headers = fw_table_headers(fw__given, fw__defaults, "`varnames'" != "")
        local N = c(N)
        local K = c(k)
        foreach f of local format {
            local path `"`fw_stem'.`f'"'
            if "`f'" == "csv" {
                mata: fw_table_csv(st_local("path"), fw__headers, "`nolabel'" != "", st_local("na"))
            }
            else {
                mata: fw_table_xlsx_labels(fw__headers)
                quietly export excel using `"`path'"', firstrow(varlabels) replace `nolabel'
            }
            mata: fw_result_record(st_local("path"), "table", "`public'" != "")
            if "`first_sha'" == "" local first_sha `"`fw_sha'"'
            local paths `"`paths' `"`path'"'"'
            mata: st_local("rel", fw_relpath(st_local("path"), st_global("fw_root")))
            display as text `"Saved table to {res}`rel'"'
        }
    }
    local rc = _rc
    restore
    capture mata: mata drop fw__given fw__defaults fw__headers
    if `rc' exit `rc'

    local first : word 1 of `paths'
    return local path `"`first'"'
    return local paths `"`paths'"'
    return local sha256 `"`first_sha'"'
    return local format `"`format'"'
    return scalar public = ("`public'" != "")
    return scalar N = `N'
    return scalar k = `K'
end
