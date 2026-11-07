* Publishing: bundles, the folder driver, private paths, and estimates.

t_tmpdir
local root `"`r(dir)'"'
mkdir `"`root'/outputs"'
mkdir `"`root'/outputs/figures"'
t_write `"`root'/settings.yml"' ///
    "default:" ///
    "  directories:" ///
    "    outputs_figures: outputs/figures" ///
    "  publish:" ///
    "    default: lab" ///
    "    destinations:" ///
    "      lab:" ///
    "        driver: folder" ///
    "        path: site" ///
    "        url: https://example.org/results" ///
    "        visibility: public" ///
    "      plain:" ///
    "        driver: folder" ///
    "        path: site-plain"
quietly cd `"`root'"'
fw_project, quietly

t_begin publish: a figure goes to the default folder destination
capture noisily {
    * A fixture image keeps these tests independent of graph settings.
    copy `"$FW_TEST_REPO/tests/fixtures/figure.png"' `"`root'/outputs/figures/price-mpg.png"'
    fw_publish "outputs/figures/price-mpg.png", title("Price and mileage") description("Synthetic example")
    t_eq `"`r(driver)'"' "folder"
    t_eq `"`r(backend)'"' "core"
    t_eq `"`r(slug)'"' "price-mpg"
    t_eq `"`r(version)'"' "1"
    t_eq `"`r(url)'"' "https://example.org/results/price-mpg/"
    confirm file `"`root'/site/price-mpg/index.html"'
    confirm file `"`root'/site/price-mpg/price-mpg.png"'
    confirm file `"`root'/site/price-mpg/v/1/artifact.json"'
    confirm file `"`root'/site/index.json"'
    confirm file `"`root'/site/index.html"'
}
t_end `=_rc'

t_begin publish: the manifest lists every file with its checksum
capture noisily {
    mata: A = fw_json_read(st_local("root") + "/site/price-mpg/artifact.json")
    mata: assert(fw_get(A, "schema") == "framework.bundle/v1")
    mata: assert(fw_get(A, "kind") == "image")
    mata: assert(fw_get(A, "title") == "Price and mileage")
    mata: assert(fw_get(A, "source.language") == "stata")
    mata: assert(fw_get(A, "files.#") == "2")
    mata: d = fw_scratch()
    mata: assert(fw_get(A, "files.1.sha256") == fw_sha256(st_local("root") + "/site/price-mpg/price-mpg.png", d)[1])
    mata: assert(strtoreal(fw_get(A, "files.1.bytes")) == fw_filesize(st_local("root") + "/site/price-mpg/price-mpg.png"))
    mata: fw_scratch_done(d)
    mata: I = fw_json_read(st_local("root") + "/site/index.json")
    mata: assert(fw_get(I, "0.slug") == "price-mpg")
}
t_end `=_rc'

t_begin publish: a second publish adds version 2 and keeps version 1
capture noisily {
    fw_publish "outputs/figures/price-mpg.png", title("Price and mileage, revised")
    t_eq `"`r(version)'"' "2"
    confirm file `"`root'/site/price-mpg/v/1/price-mpg.png"'
    confirm file `"`root'/site/price-mpg/v/2/price-mpg.png"'
    mata: A = fw_json_read(st_local("root") + "/site/price-mpg/artifact.json")
    mata: assert(fw_get(A, "title") == "Price and mileage, revised")
}
t_end `=_rc'

t_begin publish: estimates become a model with the offline reader
capture noisily {
    sysuse auto, clear
    regress price mpg weight
    fw_publish, estimates slug(price-model) saving("outputs/price-model.json", replace)
    t_eq `"`r(slug)'"' "price-model"
    confirm file `"`root'/outputs/price-model.json"'
    confirm file `"`root'/site/price-model/representation.json"'
    mata: A = fw_json_read(st_local("root") + "/site/price-model/artifact.json")
    mata: assert(fw_get(A, "kind") == "model")
    mata: assert(fw_get(A, "representation") == "representation.json")
    mata: assert(fw_get(A, "title") == "regress: price")
    mata: h = fw_readfile(st_local("root") + "/site/price-model/index.html")
    mata: assert(strpos(h, "__FRAMEWORK_ARTIFACT__") == 0)
    mata: assert(strpos(h, char(34) + "framework.artifact/v1" + char(34)) > 0)
    mata: assert(strpos(h, "<title>regress: price</title>") > 0)
}
t_end `=_rc'

t_begin publish: saving() refuses to overwrite without replace
capture noisily {
    capture fw_publish, estimates saving("outputs/price-model.json")
    assert _rc == 602
}
t_end `=_rc'

t_begin publish: private paths stop batch publishing without the option
capture noisily {
    mkdir `"`root'/outputs/private"'
    copy `"`root'/outputs/figures/price-mpg.png"' `"`root'/outputs/private/secret.png"'
    capture noisily fw_publish "outputs/private/secret.png"
    assert _rc == 198
    capture confirm file `"`root'/site/secret/index.html"'
    assert _rc
    fw_publish "outputs/private/secret.png", includeprivate
    confirm file `"`root'/site/secret/index.html"'
}
t_end `=_rc'

t_begin publish: private sets visibility(private) and does not confirm private paths
capture noisily {
    t_log_begin
    capture noisily fw_publish "outputs/figures/price-mpg.png", private visibility(public)
    local rc1 = _rc
    * lab is public, so visibility(private) does not match it.
    capture noisily fw_publish "outputs/figures/price-mpg.png", private
    local rc2 = _rc
    copy `"`root'/outputs/figures/price-mpg.png"' `"`root'/outputs/private/other.png"'
    capture noisily fw_publish "outputs/private/other.png", private
    local rc3 = _rc
    t_log_end
    assert `rc1' == 198 & `rc2' == 198 & `rc3' == 198
    t_log_has "It cannot go with"
    t_log_has "visibility(public)."
    t_log_has "Folder visibility must match"
    t_log_has "add the includeprivate option"
    capture confirm file `"`root'/site/other/index.html"'
    assert _rc
}
t_end `=_rc'

t_begin publish: folder visibility must match the destination
capture noisily {
    capture fw_publish "outputs/figures/price-mpg.png", visibility(private)
    assert _rc == 198
}
t_end `=_rc'

t_begin publish: unknown destinations and missing files give clear errors
capture noisily {
    t_log_begin
    capture noisily fw_publish "outputs/figures/price-mpg.png", to(nowhere)
    local rc = _rc
    t_log_end
    assert `rc' == 198
    t_log_has "Named destinations: lab, plain"
    capture fw_publish "outputs/figures/missing.png"
    assert _rc == 601
    capture fw_publish
    assert _rc == 198
}
t_end `=_rc'

t_begin publish: GitHub without a backend under fw_set backend core
capture noisily {
    global FW_BACKEND core
    capture noisily fw_publish "outputs/figures/price-mpg.png", to(github)
    assert _rc == 198
    global FW_BACKEND
}
t_end `=_rc'

t_begin publish: an HTML report keeps its _files folder
capture noisily {
    mkdir `"`root'/outputs/report_files"'
    t_write `"`root'/outputs/report.html"' "<!doctype html><title>Report</title><img src=report_files/a.png>"
    copy `"`root'/outputs/figures/price-mpg.png"' `"`root'/outputs/report_files/a.png"'
    fw_publish "outputs/report.html", title("Report")
    confirm file `"`root'/site/report/index.html"'
    confirm file `"`root'/site/report/report_files/a.png"'
    mata: A = fw_json_read(st_local("root") + "/site/report/artifact.json")
    mata: assert(fw_get(A, "kind") == "html")
}
t_end `=_rc'

t_begin publish: stcox gets its own default name
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly stcox age
    fw_publish, estimates
    t_eq `"`r(slug)'"' "stcox-t"
    mata: A = fw_json_read(st_local("root") + "/site/stcox-t/artifact.json")
    mata: assert(fw_get(A, "title") == "stcox: _t")
}
t_end `=_rc'

t_begin publish: r(file) after estimates names the saved copy
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    fw_publish, estimates slug(file-check)
    t_eq `"`r(file)'"' ""
    fw_publish, estimates slug(file-check) saving("outputs/file-check.json", replace)
    t_eq `"`r(file)'"' `"`root'/outputs/file-check.json"'
    confirm file `"`r(file)'"'
    fw_publish "outputs/figures/price-mpg.png", slug(file-check-2)
    t_eq `"`r(file)'"' `"`root'/outputs/figures/price-mpg.png"'
}
t_end `=_rc'

t_begin publish: to(folder) and an unset visibility name the fix
capture noisily {
    t_log_begin
    capture noisily fw_publish "outputs/figures/price-mpg.png", to(folder)
    local rc1 = _rc
    capture noisily fw_publish "outputs/figures/price-mpg.png", to(plain) visibility(private)
    local rc2 = _rc
    t_log_end
    assert `rc1' == 198 & `rc2' == 198
    t_log_has "to(folder) needs a folder"
    t_log_has "sets no visibility"
    t_log_lacks "configured visibility ()"
    * Without visibility() the destination works.
    fw_publish "outputs/figures/price-mpg.png", to(plain)
    t_eq `"`r(location)'"' `"`root'/site-plain/price-mpg"'
}
t_end `=_rc'

t_begin publish: estimates fit to private data need includeprivate
capture noisily {
    capture mkdir `"`root'/outputs/private"'
    sysuse auto, clear
    fw_save "outputs/private/cars.dta", replace
    quietly regress price mpg
    t_log_begin
    capture noisily fw_publish, estimates slug(private-model)
    local rc = _rc
    t_log_end
    assert `rc' == 198
    t_log_has "these estimation results come from data in a file with 'private' in its path"
    capture confirm file `"`root'/site/private-model/index.html"'
    assert _rc
    fw_publish, estimates slug(private-model) includeprivate
    confirm file `"`root'/site/private-model/index.html"'
    * A CSV import leaves c(filename) empty; the fw_use source still counts.
    fw_save "outputs/private/cars.csv", replace
    fw_use "outputs/private/cars.csv", clear
    quietly regress price mpg
    capture fw_publish, estimates slug(private-model-2)
    assert _rc == 198
    * A plain use of another file replaces the fw_use source.
    sysuse auto, clear
    quietly regress price mpg
    fw_publish, estimates slug(public-model)
    * A plain use of a private file counts too.
    use `"`root'/outputs/private/cars.dta"', clear
    quietly regress price mpg
    capture fw_publish, estimates slug(private-model-3)
    assert _rc == 198
}
t_end `=_rc'

quietly cd `"$FW_TEST_REPO"'
