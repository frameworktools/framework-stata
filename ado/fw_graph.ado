*! fw_graph: export a graph to the figures folder and record it
*! Part of the framework package
program define fw_graph, rclass
    version 14
    syntax anything(name=fname id="figure name") [, NAME(string) FORmat(string) PUBlic ///
        NOREPlace REPLace WIDth(integer 0) HEIght(integer 0) DPI(integer 300) OPTions(string asis)]
    _fw_need_project
    gettoken fname rest : fname
    if `"`rest'"' != "" {
        display as error "Give one figure name. Use format() for more than one file type."
        exit 198
    }
    if `dpi' < 1 {
        display as error "dpi() must be at least 1."
        exit 198
    }
    local raster png tif jpg gif
    local known `raster' svg pdf eps ps emf wmf
    mata: fw_output_target("figures", st_local("fname"), "`public'" != "", tokens(st_local("known")))
    local format = lower(trim(`"`format'"'))
    if "`fw_ext'" != "" {
        if "`format'" != "" & "`format'" != "`fw_ext'" {
            display as error "The name ends in .`fw_ext', but format() is `format'."
            exit 198
        }
        local format `fw_ext'
    }
    if "`format'" == "" local format png
    local format : subinstr local format "jpeg" "jpg", word all
    local format : subinstr local format "tiff" "tif", word all
    local format : list uniq format
    foreach f of local format {
        if !`: list f in known' {
            display as error "format() takes `known' (got `f')."
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

    * Raster files default to dpi() pixels per inch of the graph's size,
    * as save_figure() uses dpi = 300 in R and Python.
    local size
    if `width' > 0 local size `size' width(`width')
    if `height' > 0 local size `size' height(`height')
    if "`size'" == "" {
        capture quietly graph describe `name'
        if !_rc & "`r(xsize)'" != "" {
            local px = round(real("`r(xsize)'") * `dpi')
            if `px' < . & `px' > 0 local size width(`px')
        }
    }
    * graph export, name() needs a graph window, which batch mode lacks.
    * Displaying the named graph makes it the current graph instead.
    if "`name'" != "" {
        capture quietly graph display `name'
        if _rc {
            display as error "No graph named `name' is in memory. graph dir lists the graphs."
            exit 111
        }
    }

    local paths
    foreach f of local format {
        local path `"`fw_stem'.`f'"'
        local opts `options'
        if `: list f in raster' local opts `opts' `size'
        quietly graph export `"`path'"', replace `opts'
        mata: fw_result_record(st_local("path"), "figure", "`public'" != "")
        if "`first_sha'" == "" local first_sha `"`fw_sha'"'
        local paths `"`paths' `"`path'"'"'
        mata: st_local("rel", fw_relpath(st_local("path"), st_global("fw_root")))
        display as text `"Saved figure to {res}`rel'"'
    }
    local first : word 1 of `paths'
    return local path `"`first'"'
    return local paths `"`paths'"'
    return local sha256 `"`first_sha'"'
    return local format `"`format'"'
    return scalar public = ("`public'" != "")
end
