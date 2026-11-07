*! fw_publish.mata: framework.bundle/v1 bundles, the folder driver, and Cloud uploads
*! Loaded by _fw_init. Do not run directly.
*
* Mirrors framework-py's publish_bundle.py, so a folder published from Stata
* reads the same as one published from R or Python.

version 14

mata:
mata set matastrict off

// ---------------------------------------------------------------------------
// Destinations
// ---------------------------------------------------------------------------

// Resolve to() against publish.destinations and publish.default. Sets locals
// fw_dest (name), fw_driver, fw_dest_path, fw_dest_url, fw_dest_visibility.
void fw_destination(string scalar to)
{
    S = fw_S()
    selected = to
    if (selected == "") selected = fw_setting(S, "publish.default")
    if (selected == "") selected = "cloud"
    driver = ""
    if (asarray_contains(S, "publish.destinations." + selected + ".driver") |
        anyof(fw_children(S, "publish.destinations"), selected)) {
        driver = strlower(fw_setting(S, "publish.destinations." + selected + ".driver"))
        base = "publish.destinations." + selected + "."
    }
    else {
        driver = selected
        base = ""
    }
    if (driver == "bucket") driver = "s3"
    if (!anyof(("cloud", "github", "folder", "s3"), driver)) {
        named = fw_children(S, "publish.destinations")
        fw_error("to() must be cloud, github, folder, s3, or a destination named in the project settings (got " + selected + ")." + fw_nl() +
            (cols(named) ? "Named destinations: " + invtokens(named, ", ") :
                "This project names no destinations. Add them under publish.destinations in settings.yml."), 198)
    }
    path = (base != "" ? fw_setting(S, base + "path") : "")
    url = (base != "" ? fw_setting(S, base + "url") : "")
    vis = (base != "" ? strlower(fw_setting(S, base + "visibility")) : "")
    priv = (base != "" ? strlower(fw_setting(S, base + "private")) : "")
    if (vis == "" & priv != "") vis = (anyof(("true", "yes", "on"), priv) ? "private" : "public")
    if (path != "") path = fw_abs(path, asarray(S, "__root"))
    st_local("fw_dest", selected)
    st_local("fw_driver", driver)
    st_local("fw_dest_path", path)
    st_local("fw_dest_url", url)
    st_local("fw_dest_visibility", vis)
}

// Files a publish would read, for the private-path check.
string colvector fw_publish_sources(string scalar path)
{
    out = fw_abs(path)
    ext = fw_ext(path)
    if (ext == ".html" | ext == ".htm") {
        assets = fw_dirname(fw_abs(path)) + "/" + fw_stem(path) + "_files"
        if (direxists(assets)) {
            files = fw_walk(assets)
            for (i = 1; i <= rows(files); i++) out = out \ (assets + "/" + files[i])
        }
    }
    return(out)
}

string colvector fw_private_flagged(string colvector files)
{
    out = J(0, 1, "")
    for (i = 1; i <= rows(files); i++) if (fw_is_private(files[i])) out = out \ files[i]
    return(out)
}

// What a publish of path covers: one file, a folder (every file in it and its
// subfolders), or a wildcard such as outputs/figures/*.png (the matching
// files in that folder). Sets locals file (absolute), fw_isdir, and fw_wild,
// and the externals fw__srcdir and fw__selected (paths inside the folder).
void fw_publish_select(string scalar path)
{
    if ((sel = findexternal("fw__selected")) == NULL) sel = crexternal("fw__selected")
    if ((src = findexternal("fw__srcdir")) == NULL) src = crexternal("fw__srcdir")
    full = fw_abs(path)
    base = fw_basename(full)
    *sel = J(0, 1, "")
    *src = ""
    st_local("fw_isdir", "0")
    st_local("fw_wild", "0")
    st_local("file", full)
    if (direxists(full)) {
        *src = full
        *sel = fw_walk(full)
        if (rows(*sel) == 0) fw_error("The folder " + full + " has no files to publish.", 601)
        st_local("fw_isdir", "1")
        return
    }
    if (strpos(base, "*") | strpos(base, "?")) {
        folder = fw_dirname(full)
        if (!direxists(folder)) fw_error("Folder not found: " + folder, 601)
        *src = folder
        *sel = sort(dir(folder, "files", base, 0), 1)
        if (rows(*sel) == 0) fw_error("No files match " + full + ".", 601)
        st_local("fw_isdir", "1")
        st_local("fw_wild", "1")
        st_local("file", folder)
    }
}

// The files a publish reads, for the private-path check.
string colvector fw_publish_files(string scalar file, real scalar isdir)
{
    if (!isdir) return(fw_publish_sources(file))
    return(*findexternal("fw__srcdir") :+ "/" :+ *findexternal("fw__selected"))
}

// Copy the selected files into a staging folder, keeping their paths.
void fw_stage_selected(string scalar srcdir, string colvector files, string scalar stage)
{
    fw_mkdirp(stage)
    for (i = 1; i <= rows(files); i++) {
        fw_mkdirp(fw_dirname(stage + "/" + files[i]))
        fw_copy(srcdir + "/" + files[i], stage + "/" + files[i])
    }
}

// A folder with no page of its own gets an index.html that links each file,
// as framework-py writes for a published folder.
void fw_dir_index(string scalar folder)
{
    if (fileexists(folder + "/index.html")) return
    files = fw_walk(folder)
    links = ""
    for (i = 1; i <= rows(files); i++) {
        links = links + "<li><a href=" + fw_dq() + fw_url_quote(files[i]) + fw_dq() + ">" + fw_html_escape(files[i]) + "</a></li>"
    }
    fw_writefile(folder + "/index.html", "<!doctype html><meta charset=" + fw_dq() + "utf-8" + fw_dq() + "><title>Files</title><ul>" + links + "</ul>")
}

// ---------------------------------------------------------------------------
// Bundles
// ---------------------------------------------------------------------------

string scalar fw_html_escape(string scalar s_in)
{
    s = subinstr(s_in, "&", "&amp;")
    s = subinstr(s, "<", "&lt;")
    s = subinstr(s, ">", "&gt;")
    s = subinstr(s, fw_dq(), "&quot;")
    s = subinstr(s, fw_sq(), "&#x27;")
    return(s)
}

// Percent-encode a slug for links, as urllib.parse.quote does.
string scalar fw_url_quote(string scalar s)
{
    out = ""
    for (i = 1; i <= strlen(s); i++) {
        ch = substr(s, i, 1)
        if (regexm(ch, "^[A-Za-z0-9_.~/-]$")) out = out + ch
        else out = out + "%" + strupper(inbase(16, ascii(ch)))
    }
    return(out)
}

string scalar fw_reader_html(string scalar manifest, string scalar representation, string scalar title)
{
    rc = _stata("quietly findfile fw_reader_html.ihlp")
    if (rc) fw_error("The framework package is incomplete: fw_reader_html.ihlp is missing. Reinstall the package.", 601)
    tpl = fw_readfile(st_global("r(fn)"))
    payload = "{" + fw_json_str("manifest") + ":" + manifest + "," + fw_json_str("representation") + ":" +
        (representation == "" ? "null" : representation) + "}"
    payload = subinstr(payload, "&", char(92) + "u0026")
    payload = subinstr(payload, "<", char(92) + "u003c")
    payload = subinstr(payload, ">", char(92) + "u003e")
    payload = subinstr(payload, uchar(8232), char(92) + "u2028")
    payload = subinstr(payload, uchar(8233), char(92) + "u2029")
    tpl = subinstr(tpl, "__FRAMEWORK_TITLE__", fw_html_escape(title))
    // The payload goes in last, so its text is never searched for placeholders.
    k = strpos(tpl, "__FRAMEWORK_ARTIFACT__")
    if (k == 0) fw_error("The artifact reader template is damaged. Reinstall the package.", 610)
    return(substr(tpl, 1, k - 1) + payload + substr(tpl, k + strlen("__FRAMEWORK_ARTIFACT__"), .))
}

// The source object of a representation, rebuilt from its parsed form.
string scalar fw__source_json(transmorphic R)
{
    lang = fw_get(R, "source.language")
    if (lang == "") lang = "stata"
    s = "{" + fw_json_str("language") + ":" + fw_json_str(lang)
    n = strtoreal(fw_get(R, "source.class.#"))
    if (n < .) {
        s = s + "," + fw_json_str("class") + ":["
        for (i = 0; i < n; i++) s = s + (i ? "," : "") + fw_json_str(fw_get(R, "source.class." + strofreal(i)))
        s = s + "]"
    }
    return(s + "}")
}

// Build a framework.bundle/v1 folder from one file. Returns the manifest JSON.
// Sets locals fw_slug, fw_kind, fw_title.
string scalar fw_bundle_build(string scalar src_in, string scalar target, string scalar slug_in,
    string scalar title_in, string scalar descr, string scalar kind_in, string scalar dir)
{
    src = fw_abs(src_in)
    slug = slug_in
    title = title_in
    kind = kind_in
    if (!fileexists(src)) fw_error("File not found: " + src, 601)
    fw_mkdirp(target)
    name = fw_stem(src)
    ext = fw_ext(src)
    base = fw_basename(src)
    rep = ""
    source = fw_json_str("language") + ":" + fw_json_str("stata")
    source = "{" + source + "}"
    if (ext == ".html" | ext == ".htm") {
        fw_copy(src, target + "/" + base)
        assets = fw_dirname(src) + "/" + fw_stem(src) + "_files"
        if (direxists(assets)) fw_copytree(assets, target + "/" + fw_stem(src) + "_files")
        original = base
        if (kind == "") kind = "html"
    }
    else {
        original = base
        if (anyof(("artifact.json", "representation.json", "index.html"), original)) original = "original-" + original
        fw_copy(src, target + "/" + original)
        if (ext == ".json") {
            raw = fw_readfile(src)
            if (fw_startswith(strtrim(raw), "{")) {
                R = fw_json_parse(raw)
                if (fw_get(R, "schema") == "framework.artifact/v1") {
                    rep = strtrim(raw)
                    source = fw__source_json(R)
                    if (kind == "") kind = fw_get(R, "kind")
                }
            }
        }
        if (kind == "") kind = (anyof((".png", ".jpg", ".jpeg", ".svg", ".gif", ".webp"), ext) ? "image" : "file")
    }
    slug = fw_slug(slug != "" ? slug : name)
    if (slug == "") fw_error("An artifact name needs a letter or number. Give one with slug().", 198)
    if (title == "") title = name
    m = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.bundle/v1") + "," +
        fw_json_str("slug") + ":" + fw_json_str(slug) + "," +
        fw_json_str("title") + ":" + fw_json_str(title) + "," +
        fw_json_str("description") + ":" + fw_json_strornull(descr) + "," +
        fw_json_str("kind") + ":" + fw_json_str(kind) + "," +
        fw_json_str("entrypoint") + ":" + fw_json_str("index.html") + "," +
        fw_json_str("representation") + ":" + (rep != "" ? fw_json_str("representation.json") : "null") + "," +
        fw_json_str("original") + ":" + fw_json_str(original) + "," +
        fw_json_str("source") + ":" + source + "," +
        fw_json_str("created_at") + ":" + fw_json_str(fw_now_utc(dir)) + "," +
        fw_json_str("generator") + ":" + fw_json_str("framework-stata " + fw_version())
    if (rep != "") fw_writefile(target + "/representation.json", rep)
    if (!fileexists(target + "/index.html")) {
        if (rep == "" & kind == "html") fw_copy(target + "/" + original, target + "/index.html")
        else fw_writefile(target + "/index.html", fw_reader_html(m + "}", rep, title))
    }
    files = fw_walk(target)
    files = select(files, files :!= "artifact.json")
    full = J(rows(files), 1, "")
    for (i = 1; i <= rows(files); i++) full[i] = target + "/" + files[i]
    sums = fw_sha256(full, dir)
    if (rows(sums) & anyof(sums, "")) {
        fw_error("Publishing needs a SHA-256 tool for the bundle checksums, and none was found. Run fw_setup for details.", 601)
    }
    m = m + "," + fw_json_str("files") + ":["
    for (i = 1; i <= rows(files); i++) {
        m = m + (i > 1 ? "," : "") + "{" + fw_json_str("path") + ":" + fw_json_str(files[i]) + "," +
            fw_json_str("bytes") + ":" + fw_json_num(fw_filesize(full[i])) + "," +
            fw_json_str("sha256") + ":" + fw_json_str(sums[i]) + "}"
    }
    m = m + "]}"
    fw_writefile(target + "/artifact.json", m)
    st_local("fw_slug", slug)
    st_local("fw_kind", kind)
    st_local("fw_title", title)
    return(m)
}

// Build a framework.bundle/v1 folder from selected files of a folder, as
// framework-py builds one for a published folder: the files keep their
// paths, kind is html, and a folder without index.html gets a file list.
// Returns the manifest JSON. Sets locals fw_slug, fw_kind, fw_title.
string scalar fw_bundle_build_dir(string scalar srcdir, string colvector selected, string scalar target,
    string scalar slug_in, string scalar title_in, string scalar descr, string scalar kind_in, string scalar dir)
{
    fw_stage_selected(srcdir, selected, target)
    if (fileexists(target + "/artifact.json") | fileexists(target + "/representation.json")) {
        fw_error("A published folder cannot hold artifact.json or representation.json at its top. Framework writes those.", 198)
    }
    fw_dir_index(target)
    name = fw_basename(srcdir)
    slug = fw_slug(slug_in != "" ? slug_in : name)
    if (slug == "") fw_error("An artifact name needs a letter or number. Give one with slug().", 198)
    title = (title_in != "" ? title_in : name)
    kind = (kind_in != "" ? kind_in : "html")
    m = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.bundle/v1") + "," +
        fw_json_str("slug") + ":" + fw_json_str(slug) + "," +
        fw_json_str("title") + ":" + fw_json_str(title) + "," +
        fw_json_str("description") + ":" + fw_json_strornull(descr) + "," +
        fw_json_str("kind") + ":" + fw_json_str(kind) + "," +
        fw_json_str("entrypoint") + ":" + fw_json_str("index.html") + "," +
        fw_json_str("representation") + ":null," +
        fw_json_str("original") + ":null," +
        fw_json_str("source") + ":{" + fw_json_str("language") + ":" + fw_json_str("stata") + "}," +
        fw_json_str("created_at") + ":" + fw_json_str(fw_now_utc(dir)) + "," +
        fw_json_str("generator") + ":" + fw_json_str("framework-stata " + fw_version())
    files = fw_walk(target)
    files = select(files, files :!= "artifact.json")
    full = J(rows(files), 1, "")
    for (i = 1; i <= rows(files); i++) full[i] = target + "/" + files[i]
    sums = fw_sha256(full, dir)
    if (rows(sums) & anyof(sums, "")) {
        fw_error("Publishing needs a SHA-256 tool for the bundle checksums, and none was found. Run fw_setup for details.", 601)
    }
    m = m + "," + fw_json_str("files") + ":["
    for (i = 1; i <= rows(files); i++) {
        m = m + (i > 1 ? "," : "") + "{" + fw_json_str("path") + ":" + fw_json_str(files[i]) + "," +
            fw_json_str("bytes") + ":" + fw_json_num(fw_filesize(full[i])) + "," +
            fw_json_str("sha256") + ":" + fw_json_str(sums[i]) + "}"
    }
    m = m + "]}"
    fw_writefile(target + "/artifact.json", m)
    st_local("fw_slug", slug)
    st_local("fw_kind", kind)
    st_local("fw_title", title)
    return(m)
}

// ---------------------------------------------------------------------------
// The folder driver
// ---------------------------------------------------------------------------

// Keep immutable snapshots and rebuild a relative-link site index.
// Sets locals fw_url, fw_version, fw_version_url, fw_location.
void fw_folder_deliver(string scalar bundle, string scalar site, string scalar base_url_in, string scalar slug)
{
    base_url = base_url_in
    fw_mkdirp(site)
    target = site + "/" + slug
    if (direxists(bundle + "/v")) fw_error("The bundle folder name v is reserved for version archives.", 198)
    versions = target + "/v"
    fw_mkdirp(versions)
    have = dir(versions, "dirs", "*", 0)
    ver = 0
    for (i = 1; i <= rows(have); i++) {
        if (regexm(have[i], "^[0-9]+$")) ver = max((ver, strtoreal(have[i])))
    }
    ver++
    fw_copytree(bundle, versions + "/" + strofreal(ver))
    // Replace the current copy, keeping v/.
    items = dir(target, "files", "*", 0)
    for (i = 1; i <= rows(items); i++) fw_rm(target + "/" + items[i])
    items = dir(target, "dirs", "*", 0)
    for (i = 1; i <= rows(items); i++) {
        if (items[i] != "v" & items[i] != "." & items[i] != "..") fw_rmtree(target + "/" + items[i])
    }
    files = fw_walk(bundle)
    for (i = 1; i <= rows(files); i++) {
        fw_mkdirp(fw_dirname(target + "/" + files[i]))
        fw_copy(bundle + "/" + files[i], target + "/" + files[i])
    }
    // Site index from every artifact folder.
    dirs = sort(dir(site, "dirs", "*", 0), 1)
    entries = J(1, 0, "")
    rows_html = ""
    for (i = 1; i <= rows(dirs); i++) {
        f = site + "/" + dirs[i] + "/artifact.json"
        if (!fileexists(f)) continue
        E = fw_json_read(f)
        es = fw_get(E, "slug")
        et = fw_get(E, "title")
        entries = entries, "{" + fw_json_str("slug") + ":" + fw_json_strornull(es) + "," +
            fw_json_str("title") + ":" + fw_json_strornull(et) + "," +
            fw_json_str("kind") + ":" + fw_json_strornull(fw_get(E, "kind")) + "," +
            fw_json_str("description") + ":" + fw_json_strornull(fw_get(E, "description")) + "}"
        rows_html = rows_html + "<li><a href=" + fw_dq() + fw_url_quote(es) + "/" + fw_dq() + ">" + fw_html_escape(et) + "</a></li>"
    }
    fw_writefile(site + "/index.json", "[" + invtokens(entries, ",") + "]")
    fw_writefile(site + "/index.html",
        "<!doctype html><html lang=" + fw_dq() + "en" + fw_dq() + "><meta charset=" + fw_dq() + "utf-8" + fw_dq() +
        "><meta name=" + fw_dq() + "viewport" + fw_dq() + " content=" + fw_dq() + "width=device-width,initial-scale=1" + fw_dq() +
        "><title>Artifacts</title><style>body{font:16px system-ui;max-width:60rem;margin:3rem auto;padding:0 1rem}" +
        "li{margin:1rem 0}</style><h1>Artifacts</h1><ul>" + rows_html + "</ul></html>")
    url = ""
    vurl = ""
    if (base_url != "") {
        while (fw_endswith(base_url, "/")) base_url = substr(base_url, 1, strlen(base_url) - 1)
        url = base_url + "/" + slug + "/"
        vurl = url + "v/" + strofreal(ver) + "/"
    }
    st_local("fw_url", url)
    st_local("fw_version", strofreal(ver))
    st_local("fw_version_url", vurl)
    st_local("fw_location", target)
}

// Record a non-Cloud delivery on the linked Cloud project. Metadata only.
void fw_track_external(string scalar root, string scalar bundle, string scalar manifest,
    string scalar driver, string scalar visibility)
{
    url = fw_cloud_url(root)
    d = fw_scratch()
    status = fw_http("me", "GET", url + "/api/v1/me", "project", root, d, "", J(0, 3, ""), 30)
    if (status == -3) {
        fw_scratch_done(d)
        return
    }
    if (status != 200) {
        printf("{txt}Published, but Cloud tracking failed: %s\n", fw_http_reason(status, d, "me", url))
        fw_scratch_done(d)
        return
    }
    M = fw_json_read(d + "/me.json")
    pslug = fw_get(M, "project.slug")
    if (pslug == "") pslug = fw_get(M, "project")
    if (pslug == "") pslug = fw_get(M, "slug")
    if (pslug == "") {
        printf("{txt}Published, but Cloud tracking failed: the project token did not identify a project.\n")
        fw_scratch_done(d)
        return
    }
    A = fw_json_parse(manifest)
    files = fw_walk(bundle)
    size = 0
    for (i = 1; i <= rows(files); i++) size = size + fw_filesize(bundle + "/" + files[i])
    sha = fw_sha256(bundle + "/artifact.json", d)[1]
    R = fw_json_parse(fw_readfile(bundle + "/artifact.json"))
    body = "{" + fw_json_str("slug") + ":" + fw_json_str(fw_get(A, "slug")) + "," +
        fw_json_str("title") + ":" + fw_json_str(fw_get(A, "title")) + "," +
        fw_json_str("kind") + ":" + fw_json_str(fw_get(A, "kind")) + "," +
        fw_json_str("description") + ":" + fw_json_strornull(fw_get(A, "description")) + "," +
        fw_json_str("source") + ":" + fw__source_json(R) + "," +
        fw_json_str("driver") + ":" + fw_json_str(driver) + "," +
        fw_json_str("url") + ":" + fw_json_strornull(st_local("fw_url")) + "," +
        fw_json_str("version") + ":" + st_local("fw_version") + "," +
        fw_json_str("version_url") + ":" + fw_json_strornull(st_local("fw_version_url")) + "," +
        fw_json_str("size_bytes") + ":" + fw_json_num(size) + "," +
        fw_json_str("sha256") + ":" + fw_json_str(sha) + "," +
        fw_json_str("published_at") + ":" + fw_json_str(fw_get(A, "created_at")) + "," +
        fw_json_str("visibility") + ":" + fw_json_str(visibility != "" ? visibility : "public") + "}"
    status = fw_http("track", "POST", url + "/api/v1/projects/" + fw_url_quote(pslug) + "/artifacts/external",
        "project", root, d, body, J(0, 3, ""), 30)
    if (status < 200 | status >= 300) {
        printf("{txt}Published, but Cloud tracking failed: %s\n", fw_http_reason(status, d, "track", url))
    }
    fw_scratch_done(d)
}

// ---------------------------------------------------------------------------
// Framework Cloud
// ---------------------------------------------------------------------------

// Upload one file, or an HTML page with its _files folder, to the project.
// Sets locals fw_url, fw_version, fw_version_url, fw_notice, fw_id.
void fw_cloud_publish(string scalar root, string scalar src_in, string scalar slug, string scalar title,
    string scalar descr, string scalar kind, string scalar visibility)
{
    url = fw_cloud_url(root)
    d = fw_scratch()
    if (!fw_have_curl(d)) {
        fw_scratch_done(d)
        fw_error("Publishing to Framework Cloud needs curl. It ships with macOS, Linux, and Windows 10 or later. Run fw_setup for details.", 601)
    }
    // Stop before the upload message when no project token is set.
    if (!fw_have_project_token(root)) {
        fw_scratch_done(d)
        fw_error("Publishing failed. " + fw_http_reason(-3, d, "publish", url), 677)
    }
    src = fw_abs(src_in)
    ext = fw_ext(src)
    form = J(0, 3, "")
    assets = fw_dirname(src) + "/" + fw_stem(src) + "_files"
    if (direxists(src)) {
        // A folder goes as a zip with its front page: index.html, else the
        // first page at its top. The caller adds a file list when it has none.
        pages = sort(dir(src, "files", "*.htm*", 0), 1)
        entry = (anyof(pages, "index.html") ? "index.html" : (rows(pages) ? pages[1] : ""))
        if (entry == "") {
            fw_scratch_done(d)
            fw_error("The folder " + src + " has no HTML page at its top to open.", 198)
        }
        top = sort(dir(src, "files", "*", 0), 1) \ sort(dir(src, "dirs", "*", 0), 1)
        top = select(top, top :!= "." :& top :!= "..")
        args = ""
        for (i = 1; i <= rows(top); i++) args = args + " " + fw_cq(top[i])
        zip = d + "/bundle.zip"
        here = pwd()
        chdir(src)
        rc = _stata("quietly zipfile" + args + ", saving(" + fw_cq(zip) + ", replace)", 1)
        chdir(here)
        if (rc) {
            fw_scratch_done(d)
            fw_error("Could not zip the folder " + src + ".", rc)
        }
        form = form \ ("bundle", zip, "1") \ ("entrypoint", entry, "0")
    }
    else if ((ext == ".html" | ext == ".htm") & direxists(assets)) {
        stage = d + "/bundle"
        fw_mkdirp(stage)
        fw_copy(src, stage + "/" + fw_basename(src))
        fw_copytree(assets, stage + "/" + fw_stem(src) + "_files")
        zip = d + "/bundle.zip"
        here = pwd()
        chdir(stage)
        rc = _stata("quietly zipfile " + fw_cq(fw_basename(src)) + " " + fw_cq(fw_stem(src) + "_files") + ", saving(" + fw_cq(zip) + ", replace)", 1)
        chdir(here)
        if (rc) {
            fw_scratch_done(d)
            fw_error("Could not zip " + fw_basename(src) + " and its " + fw_stem(src) + "_files folder.", rc)
        }
        form = form \ ("bundle", zip, "1") \ ("entrypoint", fw_basename(src), "0")
    }
    else form = form \ ("file", src, "1")
    name = (slug != "" ? slug : (direxists(src) ? fw_basename(src) : fw_stem(src)))
    if (regexm(name, "^(.*)[.]html?$")) name = regexs(1)
    form = form \ ("slug", name, "0")
    // Visibility goes only when asked for. Cloud keeps an artifact's current
    // visibility without it, and makes a new one unlisted.
    if (title != "") form = form \ ("title", title, "0")
    if (descr != "") form = form \ ("description", descr, "0")
    if (kind != "") form = form \ ("kind", kind, "0")
    if (visibility != "") form = form \ ("visibility", visibility, "0")
    printf("{txt}Uploading %s to %s\n", fw_basename(src), fw_url_host(url))
    status = fw_http("publish", "POST", url + "/api/v1/documents", "project", root, d, "", form, 600)
    if (status < 200 | status >= 300) {
        msg = fw_http_reason(status, d, "publish", url)
        fw_scratch_done(d)
        fw_error("Publishing failed. " + msg, 677)
    }
    J = fw_json_read(d + "/publish.json")
    fw_scratch_done(d)
    st_local("fw_url", fw_get(J, "url"))
    st_local("fw_version", fw_get(J, "version"))
    st_local("fw_version_url", fw_get(J, "version_url"))
    st_local("fw_notice", fw_get(J, "notice"))
    st_local("fw_id", fw_get(J, "id"))
    // The slug Cloud stored, else the one sent.
    rslug = fw_get(J, "slug")
    st_local("fw_slug", rslug != "" ? rslug : fw_slug(name))
}

// Whether the project has a project token, without reading it into a macro.
real scalar fw_have_project_token(string scalar root)
{
    return(fw_env("FW_PROJECT_TOKEN") != "" | (root != "" & fw_dotenv(root, "FW_PROJECT_TOKEN") != ""))
}

// ---------------------------------------------------------------------------
// Backends
// ---------------------------------------------------------------------------

// The fw executable, from fw_set fw_path or the PATH. "" when absent.
// A stored fw_path that no longer exists falls back to the PATH search.
string scalar fw_find_fw(string scalar dir)
{
    p = fw_conf_get("fw_path")
    // fileexists("") is an error, and & does not short-circuit.
    if (p != "") {
        if (fileexists(p)) return(p)
    }
    return(fw_which(fw_windows() ? "fw.exe" : "fw", dir))
}

// The stored fw_path when it no longer exists, else "".
string scalar fw_fw_path_stale()
{
    p = fw_conf_get("fw_path")
    if (p == "") return("")
    return(fileexists(p) ? "" : p)
}

string scalar fw_find_fw_quick()
{
    d = fw_scratch()
    p = fw_find_fw(d)
    fw_scratch_done(d)
    return(p)
}

// Arguments for the Python bridge, as a JSON file.
void fw_bridge_args(string scalar file, string scalar src, string scalar to, string scalar slug,
    string scalar title, string scalar descr, string scalar kind, string scalar visibility,
    real scalar include_private)
{
    fw_writefile(file, "{" + fw_json_str("path") + ":" + fw_json_str(fw_abs(src)) + "," +
        fw_json_str("to") + ":" + fw_json_str(to) + "," + fw_json_str("slug") + ":" + fw_json_str(slug) + "," +
        fw_json_str("title") + ":" + fw_json_str(title) + "," + fw_json_str("description") + ":" + fw_json_str(descr) + "," +
        fw_json_str("kind") + ":" + fw_json_str(kind) + "," + fw_json_str("visibility") + ":" + fw_json_str(visibility) + "," +
        fw_json_str("include_private") + ":" + fw_json_bool(include_private) + "}")
}

void fw_bridge_result(string scalar file)
{
    if (!fileexists(file)) fw_error("framework-py returned no result.", 677)
    J = fw_json_read(file)
    if (fw_get(J, "ok") != "true") fw_error("framework-py: " + fw_get(J, "error"), 677)
    st_local("fw_url", fw_get(J, "url"))
    st_local("fw_version", fw_get(J, "version"))
    st_local("fw_version_url", fw_get(J, "version_url"))
    // framework-py reports a folder relative to the current folder.
    loc = fw_get(J, "location")
    st_local("fw_location", loc != "" ? fw_abs(loc) : "")
    if (fw_get(J, "slug") != "") st_local("fw_slug", fw_get(J, "slug"))
}

// The artifact name a backend uses when it does not report one.
string scalar fw_default_slug(string scalar src, string scalar slug)
{
    name = (slug != "" ? slug : (direxists(src) ? fw_basename(src) : fw_stem(src)))
    return(fw_slug(name))
}

// Publish through fw. Sets the receipt locals.
void fw_cli_publish(string scalar fw, string scalar src, string scalar to, string scalar slug,
    string scalar title, string scalar descr, string scalar kind, string scalar visibility,
    real scalar include_private, string scalar root)
{
    d = fw_scratch()
    q = (fw_windows() ? fw_dq() : fw_sq())
    arg = J(1, 0, "")
    arg = arg, "publish", fw_abs(src), "--json", "--yes"
    if (to != "") arg = arg, "--to", to
    if (slug != "") arg = arg, "--slug", slug
    if (title != "") arg = arg, "--title", title
    if (descr != "") arg = arg, "--description", descr
    if (kind != "") arg = arg, "--kind", kind
    if (visibility != "") arg = arg, "--visibility", visibility
    if (include_private) arg = arg, "--include-private"
    cmd = (fw_windows() ? fw_dq() + fw + fw_dq() : fw_shq(fw))
    for (i = 1; i <= cols(arg); i++) cmd = cmd + " " + fw__cliarg(arg[i])
    if (!fw_windows()) cmd = "cd " + fw_shq(root) + " && " + cmd
    else cmd = "cd /d " + fw_dq() + subinstr(root, "/", char(92)) + fw_dq() + " && " + cmd
    rc = fw_run(cmd, d, 900)
    out = fw_run_out(d)
    err = fw_run_err(d)
    fw_scratch_done(d)
    if (rc) {
        msg = fw_clean(err)
        if (fw_startswith(msg, "{")) {
            E = fw_json_parse(msg)
            if (fw_get(E, "error") != "") msg = fw_get(E, "error")
        }
        fw_error("fw publish failed (exit " + strofreal(rc) + "): " + msg, 677)
    }
    J = fw_json_parse(out)
    st_local("fw_url", fw_get(J, "url"))
    st_local("fw_version", fw_get(J, "version"))
    st_local("fw_version_url", fw_get(J, "version_url"))
    st_local("fw_notice", fw_get(J, "notice"))
    st_local("fw_location", fw_get(J, "location"))
    if (fw_get(J, "slug") != "") st_local("fw_slug", fw_get(J, "slug"))
}

string scalar fw__cliarg(string scalar s)
{
    if (fw_windows()) return(fw_dq() + subinstr(s, fw_dq(), char(92) + fw_dq()) + fw_dq())
    return(fw_shq(s))
}

end
