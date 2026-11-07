*! fw_data.mata: named datasets, checksums, and the integrity record
*! Loaded by _fw_init. Do not run directly.

version 14

mata:
mata set matastrict off

// ---------------------------------------------------------------------------
// Dataset names
// ---------------------------------------------------------------------------

// Resolve a dataset name or path. Sets locals in the caller:
//   fw_path (absolute), fw_type (dta, csv, tsv, xlsx, xls), fw_record (name
//   used in the integrity record, "" for plain paths), fw_locked (0/1),
//   fw_cataloged (0/1).
void fw_data_resolve(string scalar name_in, real scalar saving)
{
    S = fw_S()
    root = asarray(S, "__root")
    name = strtrim(name_in)
    if (name == "") fw_error("Give a dataset name, such as inputs.raw.survey, or a file path.")
    has_slash = strpos(name, "/") | strpos(name, char(92))
    ext = fw_ext(name)
    known = (ext == ".dta" | ext == ".csv" | ext == ".tsv" | ext == ".xlsx" | ext == ".xls")
    record = ""
    cataloged = 0
    locked = 0
    type = ""

    if (has_slash | known) {
        if (ext == "") {
            name = name + ".dta"
            ext = ".dta"
        }
        // A relative path is tried from the current folder, then from the
        // project root. Reading uses the current folder when the file is
        // there. Saving uses it when the file or its folder is there, so
        // fw_save never builds a new folder tree under a subfolder.
        path = fw_abs(name, pwd())
        if (!fw_isabs(name)) {
            here = (saving ? (fileexists(path) | direxists(fw_dirname(path))) : fileexists(path))
            if (!here) {
                alt = fw_abs(name, root)
                if (saving | fileexists(alt)) path = alt
            }
        }
    }
    else if (asarray_contains(S, "data." + name + ".path")) {
        cataloged = 1
        record = name
        path = fw_abs(fw_setting(S, "data." + name + ".path"), root)
        type = strlower(fw_setting(S, "data." + name + ".type"))
        locked = anyof(("true", "yes", "on", "1"), strlower(fw_setting(S, "data." + name + ".locked")))
        ext = fw_ext(path)
    }
    else {
        parts = tokens(name, ".")
        parts = select(parts, parts :!= ".")
        if (cols(parts) == 1) {
            fw_error("The dataset " + name + " is not in the data catalog and names no folder." + fw_nl() +
                "Use dot notation, such as inputs.raw." + name + ", or a file path such as inputs/raw/" + name + ".dta.", 601)
        }
        d = fw_directories(S)
        folder = ""
        for (e = cols(parts) - 1; e >= 1; e--) {
            key = invtokens(parts[|1 \ e|], "_")
            for (i = 1; i <= rows(d); i++) {
                if (d[i, 1] == key) {
                    folder = d[i, 2]
                    break
                }
            }
            if (folder != "") break
        }
        if (folder == "") {
            avail = (rows(d) ? invtokens(subinstr(d[., 1]', "_", "."), ", ") : "none")
            fw_error("No project folder matches " + name + "." + fw_nl() +
                "Available folders: " + avail, 601)
        }
        record = name
        path = folder + "/" + invtokens(parts[|e + 1 \ cols(parts)|], "_") + ".dta"
        ext = ".dta"
    }
    if (type == "") type = substr(ext, 2, .)
    if (type == "") type = "dta"
    if (!anyof(("dta", "csv", "tsv", "xlsx", "xls"), type)) {
        fw_error("Framework for Stata reads and writes .dta, .csv, .tsv, .xlsx, and .xls files." + fw_nl() +
            "The dataset " + name + " is type " + type + ".", 198)
    }
    // Records written by Stata keep their own lock flag.
    if (record != "") {
        R = fw_integrity_get(root, record)
        if (R[5] == "1") locked = 1
    }
    st_local("fw_path", path)
    st_local("fw_type", type)
    st_local("fw_record", record)
    st_local("fw_locked", strofreal(locked))
    st_local("fw_cataloged", strofreal(cataloged))
    st_local("fw_root", root)
}

// Paths compare without case where the file system ignores it.
real scalar fw_samepath(string scalar a, string scalar b)
{
    if (fw_windows() | c("os") == "MacOSX") return(ustrlower(fw_norm(a)) == ustrlower(fw_norm(b)))
    return(fw_norm(a) == fw_norm(b))
}

real scalar fw_in_root(string scalar path, string scalar root)
{
    p = fw_norm(path)
    r = fw_norm(root)
    if (fw_samepath(p, r)) return(1)
    if (strlen(p) <= strlen(r)) return(0)
    return(fw_samepath(substr(p, 1, strlen(r) + 1), r + "/"))
}

// The catalog name whose entry has locked: true and whose file is path, or "".
string scalar fw_catalog_locked_at(transmorphic S, string scalar path)
{
    root = asarray(S, "__root")
    keys = asarray_keys(S)
    for (i = 1; i <= rows(keys); i++) {
        k = keys[i]
        if (!fw_startswith(k, "data.") | !fw_endswith(k, ".path")) continue
        name = substr(k, 6, strlen(k) - 10)
        if (name == "") continue
        if (!anyof(("true", "yes", "on", "1"), strlower(fw_setting(S, "data." + name + ".locked")))) continue
        v = fw_setting(S, k)
        if (v == "") continue
        if (fw_samepath(fw_abs(v, root), path)) return(name)
    }
    return("")
}

// fw_save's write rules. A catalog entry with locked: true is source data
// that fw_save never overwrites, by name or by path; R and Python never
// write through a catalog entry either. A file outside the project root,
// such as one in a folder that a settings.do global puts above the root,
// needs the outside option.
void fw_save_guard(string scalar path, real scalar outside)
{
    S = fw_S()
    root = asarray(S, "__root")
    name = fw_catalog_locked_at(S, path)
    if (name != "") {
        fw_error("fw_save does not overwrite locked catalog data." + fw_nl() +
            "  dataset: " + name + " (locked: true in the project settings)" + fw_nl() +
            "  file:    " + path + fw_nl() +
            "Save the data under another name, such as a dot name in a project folder." + fw_nl() +
            "To replace the source file itself, set locked: false for " + name + " first.", 608)
    }
    if (!outside & !fw_in_root(path, root)) {
        fw_error("fw_save writes inside the project unless you add the outside option." + fw_nl() +
            "  file:    " + path + fw_nl() +
            "  project: " + root + fw_nl() +
            "Check the name or path. To write there on purpose, add the outside option.", 198)
    }
}

// ---------------------------------------------------------------------------
// SHA-256 through the tools that ship with each operating system
// ---------------------------------------------------------------------------

// Lowercase hex digests for each file, in order. Returns "" entries when no
// tool is available.
string colvector fw_sha256(string colvector files, string scalar dir)
{
    n = rows(files)
    out = J(n, 1, "")
    if (n == 0) return(out)
    if (fw_windows()) {
        ps = char(36) + "ErrorActionPreference = 'Stop'" + char(13) + char(10)
        for (i = 1; i <= n; i++) {
            p = subinstr(subinstr(files[i], "/", char(92)), fw_sq(), fw_sq() + fw_sq())
            ps = ps + "(Get-FileHash -Algorithm SHA256 -LiteralPath " + fw_sq() + p + fw_sq() + ").Hash.ToLower()" + char(13) + char(10)
        }
        script = subinstr(dir + "/hash.ps1", "/", char(92))
        fw_writefile(script, ps)
        rc = fw_run("powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + fw_dq() + script + fw_dq(), dir)
    }
    else {
        list = ""
        for (i = 1; i <= n; i++) list = list + " " + fw_shq(files[i])
        rc = fw_run("if command -v sha256sum >/dev/null 2>&1; then sha256sum --" + list +
            "; else shasum -a 256 --" + list + "; fi", dir)
    }
    if (rc) return(out)
    lines = tokens(subinstr(fw_run_out(dir), char(13), ""), char(10))
    lines = select(lines, lines :!= char(10))
    k = 0
    for (j = 1; j <= cols(lines); j++) {
        l = strtrim(lines[j])
        if (fw_startswith(l, char(92))) l = substr(l, 2, .)
        if (!regexm(l, "^[0-9a-fA-F]+")) continue
        h = strlower(regexs(0))
        if (strlen(h) != 64) continue
        k++
        if (k <= n) out[k] = h
    }
    return(out)
}

string scalar fw_sha256_file(string scalar file)
{
    d = fw_scratch()
    h = fw_sha256(file, d)[1]
    fw_scratch_done(d)
    return(h)
}

// SHA-256 of a string, through a temporary file.
string scalar fw_sha256_string(string scalar s, string scalar dir)
{
    f = dir + "/string.bin"
    fw_writefile(f, s)
    return(fw_sha256(f, dir)[1])
}

// ---------------------------------------------------------------------------
// The integrity record: .framework/stata-integrity.tsv
// Columns: name, path, sha256, datasignature, locked, bytes, recorded_at
// ---------------------------------------------------------------------------

string scalar fw_integrity_file(string scalar root) return(root + "/.framework/stata-integrity.tsv")

string rowvector fw_integrity_get(string scalar root, string scalar name)
{
    file = fw_integrity_file(root)
    empty = J(1, 7, "")
    if (!fileexists(file)) return(empty)
    lines = fw_readlines(file)
    for (i = 2; i <= rows(lines); i++) {
        f = fw__tsv(lines[i])
        if (cols(f) >= 7 & f[1] == name) return(f[|1 \ 7|])
    }
    return(empty)
}

string rowvector fw__tsv(string scalar line)
{
    out = J(1, 0, "")
    while (1) {
        k = strpos(line, char(9))
        if (k == 0) {
            out = out, line
            break
        }
        out = out, substr(line, 1, k - 1)
        line = substr(line, k + 1, .)
    }
    return(out)
}

void fw_integrity_put(string scalar root, string rowvector rec)
{
    file = fw_integrity_file(root)
    fw_mkdirp(root + "/.framework")
    header = "name" + char(9) + "path" + char(9) + "sha256" + char(9) + "datasignature" + char(9) +
        "locked" + char(9) + "bytes" + char(9) + "recorded_at"
    out = header + fw_nl()
    found = 0
    if (fileexists(file)) {
        lines = fw_readlines(file)
        for (i = 2; i <= rows(lines); i++) {
            if (strtrim(lines[i]) == "") continue
            f = fw__tsv(lines[i])
            if (f[1] == rec[1]) {
                out = out + invtokens(rec, char(9)) + fw_nl()
                found = 1
            }
            else out = out + lines[i] + fw_nl()
        }
    }
    if (!found) out = out + invtokens(rec, char(9)) + fw_nl()
    fw_writefile(file, out)
}

string scalar fw_local_time()
{
    d = date(c("current_date"), "DMY")
    return(strofreal(d, "%tdCCYY-NN-DD") + "T" + c("current_time"))
}

// Check a dataset against its record. mode: strict, warn, off, or accept.
// accept notes a change without a message; fw_integrity_accept records it.
// Sets locals fw_sha (current digest or "") and fw_changed (0/1).
// Stops with error 459 when a locked dataset changed and mode is strict.
void fw_integrity_check_file(string scalar root, string scalar record, string scalar path,
    real scalar locked, string scalar mode)
{
    st_local("fw_sha", "")
    st_local("fw_changed", "0")
    if (mode == "off" | record == "") return
    d = fw_scratch()
    sha = fw_sha256(path, d)[1]
    fw_scratch_done(d)
    st_local("fw_sha", sha)
    R = fw_integrity_get(root, record)
    if (R[1] == "" | R[3] == "" | sha == "") return
    if (R[3] == sha) return
    st_local("fw_changed", "1")
    if (mode == "accept") return
    msg = "The file for " + record + " changed since Framework recorded it." + fw_nl() +
        "  file:     " + path + fw_nl() +
        "  recorded: " + R[3] + " (" + R[7] + ")" + fw_nl() +
        "  current:  " + sha
    if (locked & mode == "strict") {
        fw_error(msg + fw_nl() + fw__locked_advice(record), 459)
    }
    printf("{txt}Warning: %s\n", msg)
}

// The datasignature check runs after loading. Same rules as the file check.
void fw_integrity_check_sig(string scalar root, string scalar record, string scalar sig,
    real scalar locked, string scalar mode)
{
    st_local("fw_sigchanged", "0")
    if (mode == "off" | record == "") return
    R = fw_integrity_get(root, record)
    if (R[1] == "" | R[4] == "" | R[4] == sig) return
    // A matching file digest outranks the data signature: a different
    // import option, not a different file, changes the signature.
    if (R[3] != "" & R[3] == st_local("fw_sha")) return
    st_local("fw_sigchanged", "1")
    if (mode == "accept") return
    msg = "The data in " + record + " changed since Framework recorded it." + fw_nl() +
        "  recorded datasignature: " + R[4] + " (" + R[7] + ")" + fw_nl() +
        "  current datasignature:  " + sig
    if (locked & mode == "strict") {
        fw_error(msg + fw_nl() + fw__locked_advice(record), 459)
    }
    printf("{txt}Warning: %s\n", msg)
}

// check(accept) records the file as it is now, without rewriting it.
string scalar fw__locked_advice(string scalar record)
{
    return("The dataset is locked. Check the change. To accept the file as it is now, run" + fw_nl() +
        "  fw_use " + record + ", clear check(accept)")
}

void fw_integrity_record(string scalar root, string scalar record, string scalar path,
    string scalar sha, string scalar sig, real scalar locked)
{
    if (record == "") return
    if (sha == "") {
        d = fw_scratch()
        sha = fw_sha256(path, d)[1]
        fw_scratch_done(d)
    }
    rec = (record, fw_relpath(path, root), sha, sig, strofreal(locked), strofreal(fw_filesize(path)), fw_local_time())
    fw_integrity_put(root, rec)
    st_local("fw_sha", sha)
}

// check(accept): record the dataset as it is now. Keeps the record's lock
// flag. Sets local fw_accepted: 0 unchanged, 1 change recorded, 2 first record.
void fw_integrity_accept(string scalar root, string scalar record, string scalar path,
    string scalar sha, string scalar sig, real scalar locked)
{
    st_local("fw_accepted", "0")
    R = fw_integrity_get(root, record)
    if (R[1] != "" & st_local("fw_changed") != "1" & st_local("fw_sigchanged") != "1") return
    lk = (R[1] != "" ? (R[5] == "1") : locked)
    fw_integrity_record(root, record, path, sha, sig, lk)
    st_local("fw_accepted", (R[1] == "" ? "2" : "1"))
}

// Whether the integrity ledger is live for this project.
real scalar fw_ledger_live()
{
    mode = strlower(fw_env("FW_LEDGER"))
    if (mode == "") {
        p = findexternal("fw_settings")
        if (p != NULL) mode = strlower(fw_setting(*p, "options.cloud_ledger"))
    }
    return(anyof(("live", "on", "true"), mode))
}

end
