*! fw_outputs.mata: tables and figures in the project's output folders
*! Loaded by _fw_init. Do not run directly.
*
* Mirrors save_table() and save_figure() in R and Python: the same folders,
* the same private and public split, and a record of each saved file.

version 14

mata:
mata set matastrict off

// ---------------------------------------------------------------------------
// Output folders
// ---------------------------------------------------------------------------

real scalar fw_truthy(string scalar v) return(anyof(("true", "yes", "on", "1"), strlower(strtrim(v))))

// The folder for one kind of output, as R's .output_dir() picks it. A
// project with private and public output folders (security.sensitive, or
// outputs_private_<kind> or outputs_public_<kind> directories) splits by
// public. Any other project has one folder per kind.
string scalar fw_output_dir(string scalar kind, real scalar ispublic)
{
    S = fw_S()
    root = asarray(S, "__root")
    dirs = fw_children(S, "directories")
    split = fw_truthy(fw_setting(S, "security.sensitive")) |
        anyof(dirs, "outputs_private_" + kind) | anyof(dirs, "outputs_public_" + kind)
    if (!split) {
        v = fw_setting(S, "directories.outputs_" + kind)
        return(fw_abs(v != "" ? v : "outputs/" + kind, root))
    }
    side = (ispublic ? "public" : "private")
    v = fw_setting(S, "directories.outputs_" + side + "_" + kind)
    return(fw_abs(v != "" ? v : "outputs/" + side + "/" + kind, root))
}

// Resolve an output name, such as "meeting/table-1" or "table-1.csv", to a
// path without extension in the folder for kind. Creates the folders.
// Sets locals fw_stem (absolute, no extension), fw_ext (the extension the
// name gave, without the dot, or ""), fw_dir, and fw_split.
void fw_output_target(string scalar kind, string scalar name_in, real scalar ispublic, string rowvector exts)
{
    name = fw_norm(strtrim(name_in))
    while (fw_startswith(name, "./")) name = substr(name, 3, .)
    if (name == "" | name == ".") fw_error("Give a name for the " + kind + " file, such as summary or meeting/summary.", 198)
    if (fw_isabs(name) | anyof(tokens(name, "/"), "..")) {
        fw_error("The name " + name_in + " must stay inside the " + kind + " folder: no absolute path and no .. in it." + fw_nl() +
            "Give a name such as summary or meeting/summary.", 198)
    }
    ext = fw_ext(name)
    given = ""
    if (ext != "") {
        if (anyof(exts, substr(ext, 2, .))) {
            given = substr(ext, 2, .)
            name = substr(name, 1, strlen(name) - strlen(ext))
        }
    }
    folder = fw_output_dir(kind, ispublic)
    stem = folder + "/" + name
    created = !direxists(fw_dirname(stem))
    fw_mkdirp(fw_dirname(stem))
    if (created) printf("{txt}Created the %s folder %s\n", kind, fw_relpath(fw_dirname(stem), st_global("fw_root")))
    st_local("fw_stem", stem)
    st_local("fw_ext", given)
    st_local("fw_dir", folder)
}

// ---------------------------------------------------------------------------
// The results record: .framework/stata-results.tsv
// Columns: name, type, public, sha256, bytes, created_at, updated_at
// R and Python keep the same fields in framework.db's results table.
// ---------------------------------------------------------------------------

string scalar fw_results_file(string scalar root) return(root + "/.framework/stata-results.tsv")

// Record a saved output by its path from the project root, as R and Python
// name results. Sets local fw_sha.
void fw_result_record(string scalar path, string scalar type, real scalar ispublic)
{
    root = st_global("fw_root")
    d = fw_scratch()
    sha = fw_sha256(path, d)[1]
    fw_scratch_done(d)
    name = (fw_in_root(path, root) ? fw_relpath(path, root) : fw_norm(path))
    now = fw_local_time()
    file = fw_results_file(root)
    fw_mkdirp(root + "/.framework")
    out = invtokens(("name", "type", "public", "sha256", "bytes", "created_at", "updated_at"), char(9)) + fw_nl()
    created = now
    rest = ""
    if (fileexists(file)) {
        lines = fw_readlines(file)
        for (i = 2; i <= rows(lines); i++) {
            if (strtrim(lines[i]) == "") continue
            f = fw__tsv(lines[i])
            if (f[1] == name) {
                if (cols(f) >= 6) created = f[6]
                continue
            }
            rest = rest + lines[i] + fw_nl()
        }
    }
    rec = (name, type, strofreal(ispublic != 0), sha, strofreal(fw_filesize(path)), created, now)
    fw_writefile(file, out + rest + invtokens(rec, char(9)) + fw_nl())
    st_local("fw_sha", sha)
}

// One record, or empty strings when there is none.
string rowvector fw_result_get(string scalar root, string scalar name)
{
    file = fw_results_file(root)
    if (!fileexists(file)) return(J(1, 7, ""))
    lines = fw_readlines(file)
    for (i = 2; i <= rows(lines); i++) {
        f = fw__tsv(lines[i])
        if (cols(f) >= 7 & f[1] == name) return(f[|1 \ 7|])
    }
    return(J(1, 7, ""))
}

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

// The data in memory from a matrix: a column of row names, unless they are
// Stata's defaults r1, r2, ..., then one double column per matrix column.
// Returns the matrix's column names, with a "" first for the row names.
string rowvector fw_matrix_data(string scalar mname)
{
    M = st_matrix(mname)
    if (rows(M) == 0 & cols(M) == 0) fw_error("Matrix " + mname + " not found.", 111)
    rs = st_matrixrowstripe(mname)
    cs = st_matrixcolstripe(mname)
    rn = J(rows(rs), 1, "")
    plain = 1
    for (i = 1; i <= rows(rs); i++) {
        rn[i] = (rs[i, 1] != "" & rs[i, 1] != "_" ? rs[i, 1] + ":" : "") + rs[i, 2]
        if (rn[i] != "r" + strofreal(i)) plain = 0
    }
    st_addobs(rows(M))
    heads = J(1, 0, "")
    if (!plain) {
        w = max(strlen(rn))
        (void) st_addvar(w > 2045 ? "strL" : "str" + strofreal(max((w, 1))), "_fw_row")
        st_sstore(., "_fw_row", rn)
        heads = heads, ""
    }
    for (j = 1; j <= cols(M); j++) {
        k = st_addvar("double", "_fw_c" + strofreal(j))
        st_store(., k, M[., j])
        heads = heads, (cs[j, 1] != "" & cs[j, 1] != "_" ? cs[j, 1] + ":" : "") + cs[j, 2]
    }
    return(heads)
}

// Column headers: the headers() words, else the given defaults, else each
// variable's label, or its name when it has none or with varnames.
string rowvector fw_table_headers(string rowvector given, string rowvector defaults, real scalar varnames)
{
    k = st_nvar()
    if (cols(given)) {
        if (cols(given) != k) {
            fw_error("headers() has " + strofreal(cols(given)) + " header" + (cols(given) == 1 ? "" : "s") +
                ", but the table has " + strofreal(k) + " column" + (k == 1 ? "" : "s") + ".", 198)
        }
        return(given)
    }
    if (cols(defaults)) return(defaults)
    out = J(1, k, "")
    for (j = 1; j <= k; j++) {
        lab = st_varlabel(j)
        out[j] = (lab != "" & !varnames ? lab : st_varname(j))
    }
    return(out)
}

// A CSV field, quoted when needed as readr quotes it: a comma, quote, or line
// break, or the text NA, which would otherwise read back as missing.
string colvector fw_csv_quote(string colvector s, string scalar delim)
{
    out = s
    for (i = 1; i <= rows(s); i++) {
        v = s[i]
        if (strpos(v, delim) | strpos(v, fw_dq()) | strpos(v, char(10)) | strpos(v, char(13)) | v == "NA") {
            out[i] = fw_dq() + subinstr(v, fw_dq(), fw_dq() + fw_dq()) + fw_dq()
        }
    }
    return(out)
}

// A number as R writes it: whole numbers without decimals, others with the
// fewest digits that read back as the same value. Floats use 7 significant
// digits, so a float 75.2 is written 75.2.
string scalar fw_csv_num(real scalar x, real scalar isfloat, string scalar na)
{
    if (missing(x)) return(na)
    if (x == floor(x) & abs(x) < 1e15) return(strtrim(sprintf("%18.0f", x)))
    if (isfloat) s = strtrim(strofreal(x, "%21.7g"))
    else {
        s = strtrim(strofreal(x, "%21.15g"))
        if (strtoreal(s) != x) {
            s = strtrim(strofreal(x, "%21.16g"))
            if (strtoreal(s) != x) s = strtrim(strofreal(x, "%21.17g"))
        }
    }
    k = strpos(s, "e")
    if (k) {
        mant = substr(s, 1, k - 1)
        if (strpos(mant, ".")) {
            while (fw_endswith(mant, "0")) mant = substr(mant, 1, strlen(mant) - 1)
            if (fw_endswith(mant, ".")) mant = substr(mant, 1, strlen(mant) - 1)
        }
        s = mant + substr(s, k, .)
    }
    if (fw_startswith(s, ".")) s = "0" + s
    if (fw_startswith(s, "-.")) s = "-0" + substr(s, 2, .)
    return(s)
}

// Rows r0 to r1 of one column of the data in memory as CSV text.
string colvector fw_csv_column(real scalar j, real scalar r0, real scalar r1, real scalar nolabel,
    string scalar na, string scalar delim)
{
    if (st_isstrvar(j)) return(fw_csv_quote(st_sdata((r0, r1), j), delim))
    x = st_data((r0, r1), j)
    n = rows(x)
    out = J(n, 1, "")
    fmt = st_varformat(j)
    vl = (nolabel ? "" : st_varvaluelabel(j))
    labs = J(n, 1, "")
    if (vl != "") {
        if (_stata("quietly label list " + vl, 1) == 0) labs = st_vlmap(vl, x)
    }
    isfloat = (st_vartype(j) == "float")
    datefmt = ""
    if (regexm(fmt, "^%-?t?d")) datefmt = "%tdCCYY-NN-DD"
    else if (regexm(fmt, "^%-?tc")) datefmt = "%tcCCYY-NN-DD!THH:MM:SS"
    else if (regexm(fmt, "^%-?tC")) datefmt = "%tCCCYY-NN-DD!THH:MM:SS"
    else if (regexm(fmt, "^%-?t")) datefmt = fmt
    for (i = 1; i <= n; i++) {
        if (labs[i] != "") out[i] = labs[i]
        else if (datefmt != "" & !missing(x[i])) out[i] = strtrim(strofreal(x[i], datefmt))
        else out[i] = fw_csv_num(x[i], isfloat, na)
    }
    if (vl != "" | datefmt != "") out = fw_csv_quote(out, delim)
    return(out)
}

// Write the data in memory as CSV with the given headers.
void fw_table_csv(string scalar path, string rowvector headers, real scalar nolabel, string scalar na)
{
    delim = ","
    fw_rm(path)
    fh = fopen(path, "w")
    fwrite(fh, invtokens(fw_csv_quote(headers', delim)', delim) + char(10))
    n = st_nobs()
    k = st_nvar()
    // Write in blocks of rows, so a long table needs little memory.
    step = 5000
    for (r0 = 1; r0 <= n; r0 = r0 + step) {
        r1 = min((n, r0 + step - 1))
        lines = J(r1 - r0 + 1, 1, "")
        for (j = 1; j <= k; j++) {
            col = fw_csv_column(j, r0, r1, nolabel, na, delim)
            lines = (j == 1 ? col : lines :+ delim :+ col)
        }
        fwrite(fh, invtokens(lines', char(10)) + char(10))
    }
    fclose(fh)
}

// Excel headers travel as variable labels, which hold at most 80 characters.
void fw_table_xlsx_labels(string rowvector headers)
{
    for (j = 1; j <= st_nvar(); j++) {
        h = headers[j]
        if (ustrlen(h) > 80) {
            fw_error("The header " + h + " is longer than 80 characters, the most an Excel header from Stata can hold." + fw_nl() +
                "Shorten it in headers(), or save the table as CSV only.", 198)
        }
        st_varlabel(j, h == "" ? " " : h)
    }
}

end
