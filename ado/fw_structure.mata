*! fw_structure.mata: project structure trees
*! Loaded by _fw_init. Do not run directly.
*
* fw_structure walks a project folder, finds which paths .gitignore hides and
* which folders are private, prints the tree, and writes a
* framework.artifact/v1 document of kind tree. Ignored and private paths
* publish as stubs and groups with counts, never by name. See
* docs/plans/2026-11-25-structure-artifacts.md in framework-cloud.
*
* The walk keeps each folder's entries in the external fw__tr_kids, keyed by
* the folder's path relative to the tree root ("" for the root). Each entry is
* a row of fw__tr_cols() columns:
*   1 name, 2 path, 3 type (dir, file, or ignfile: an ignored file),
*   4 private ("1"), 5 ignored ("1"), 6 depth ("1"),
*   7 rule, 8 rule source, 9 rule line, 10 hidden file count ("" when listed).

version 14

mata:
mata set matastrict off

real scalar fw__tr_cols() return(10)

// File counts stop here, and read as "10,000+ files".
real scalar fw__tr_cap() return(10000)

// ---------------------------------------------------------------------------
// Ignore patterns
// ---------------------------------------------------------------------------

string scalar fw__tr_re_esc(string scalar c)
{
    meta = ".^+(){}|[]*?" + char(92) + char(36)
    return(strpos(meta, c) ? char(92) + c : c)
}

// A .gitignore glob as an ICU regular expression body: * and ? stay inside
// one path part, ** crosses parts, [...] is a character class.
string scalar fw__tr_glob_re(string scalar p)
{
    out = ""
    n = strlen(p)
    i = 1
    while (i <= n) {
        c = substr(p, i, 1)
        if (c == "*") {
            if (substr(p, i, 2) == "**") {
                atstart = (i == 1 | substr(p, i - 1, 1) == "/")
                if (atstart & substr(p, i + 2, 1) == "/") {
                    out = out + "(.*/)?"
                    i = i + 3
                    continue
                }
                if (atstart & i + 2 > n) {
                    out = out + ".*"
                    i = i + 2
                    continue
                }
                out = out + "[^/]*"
                i = i + 2
                continue
            }
            out = out + "[^/]*"
            i++
            continue
        }
        if (c == "?") {
            out = out + "[^/]"
            i++
            continue
        }
        if (c == "[") {
            k = strpos(substr(p, i + 1, .), "]")
            if (k > 1) {
                cls = substr(p, i + 1, k - 1)
                if (substr(cls, 1, 1) == "!") cls = "^" + substr(cls, 2, .)
                out = out + "[" + cls + "]"
                i = i + k + 1
                continue
            }
        }
        if (c == char(92) & i < n) {
            out = out + fw__tr_re_esc(substr(p, i + 1, 1))
            i = i + 2
            continue
        }
        out = out + fw__tr_re_esc(c)
        i++
    }
    return(out)
}

// One pattern as a row: regular expression, folders only, negated, the rule
// as written, line. Returns J(0, 5, "") for a blank line or a comment.
string matrix fw__tr_pattern(string scalar line_in, real scalar lineno)
{
    line = line_in
    // Trailing spaces go, unless a backslash escapes them.
    while (strlen(line) & substr(line, strlen(line), 1) == " " & substr(line, strlen(line) - 1, 1) != char(92)) {
        line = substr(line, 1, strlen(line) - 1)
    }
    if (line == "" | substr(line, 1, 1) == "#") return(J(0, 5, ""))
    p = line
    neg = 0
    if (substr(p, 1, 1) == "!") {
        neg = 1
        p = substr(p, 2, .)
    }
    else if (substr(p, 1, 2) == char(92) + "!" | substr(p, 1, 2) == char(92) + "#") p = substr(p, 2, .)
    dironly = 0
    if (fw_endswith(p, "/")) {
        dironly = 1
        p = substr(p, 1, strlen(p) - 1)
    }
    if (p == "") return(J(0, 5, ""))
    // A slash at the start or in the middle anchors the pattern to the root.
    anchored = (strpos(p, "/") > 0)
    if (substr(p, 1, 1) == "/") p = substr(p, 2, .)
    re = (anchored ? "^" : "^(.*/)?") + fw__tr_glob_re(p) + char(36)
    return((re, strofreal(dironly), strofreal(neg), line, strofreal(lineno)))
}

// The patterns of a .gitignore file, or none when it is missing.
string matrix fw_tree_gitignore(string scalar file)
{
    R = J(0, 5, "")
    if (!fileexists(file)) return(R)
    L = fw_readlines(file)
    for (i = 1; i <= rows(L); i++) R = R \ fw__tr_pattern(L[i], i)
    return(R)
}

// The last pattern that matches, or 0 when none does or a ! pattern
// matches last.
real scalar fw_tree_match(string matrix R, string scalar path, real scalar isdir)
{
    hit = 0
    for (i = 1; i <= rows(R); i++) {
        if (R[i, 2] == "1" & !isdir) continue
        if (ustrregexm(path, R[i, 1])) hit = (R[i, 3] == "1" ? 0 : i)
    }
    return(hit)
}

// ---------------------------------------------------------------------------
// Git
// ---------------------------------------------------------------------------

// The parts of a NUL-separated list. tokens() stops at the first NUL.
string colvector fw__tr_split0(string scalar s)
{
    out = J(0, 1, "")
    rest = s
    while ((k = strpos(rest, char(0))) > 0) {
        out = out \ substr(rest, 1, k - 1)
        rest = substr(rest, k + 1, .)
    }
    if (rest != "") out = out \ rest
    return(out)
}

// Where a rule comes from, as published: global, info/exclude, or the file's
// path relative to the tree root, else to the project root, else to the top
// of the work tree. Git reports a .gitignore relative to the top of the work
// tree. treepre and projpre are the tree root and the project root as
// relative to it, each "" or ending in /.
string scalar fw__tr_source(string scalar src, string scalar treepre, string scalar projpre)
{
    s = subinstr(src, char(92), "/")
    if (fw_endswith(s, "info/exclude")) return("info/exclude")
    if (fw_isabs(s)) return("global")
    if (treepre != "" & fw_startswith(s, treepre)) return(substr(s, strlen(treepre) + 1, .))
    if (treepre == "") return(s)
    if (projpre != "" & fw_startswith(s, projpre)) return(substr(s, strlen(projpre) + 1, .))
    return(s)
}

// A git that runs, as a quoted command, or "". Stata 14 on an Apple silicon
// Mac runs under Rosetta, where the /usr/bin/git shim fails; the Command
// Line Tools git itself, or the shim run as arm64, works.
string scalar fw__tr_gitcmd(string scalar d)
{
    git = fw_which(fw_windows() ? "git.exe" : "git", d)
    tries = J(1, 0, "")
    if (git != "") tries = tries, fw__cliarg(git)
    if (fw_macos()) {
        clt = ("/Library/Developer/CommandLineTools/usr/bin/git", "/Applications/Xcode.app/Contents/Developer/usr/bin/git")
        for (i = 1; i <= cols(clt); i++) if (fileexists(clt[i])) tries = tries, fw_shq(clt[i])
        if (fileexists("/usr/bin/git")) tries = tries, "/usr/bin/arch -arm64 /usr/bin/git"
    }
    for (i = 1; i <= cols(tries); i++) {
        if (!fw_run(tries[i] + " --version", d, 30)) return(tries[i])
    }
    return("")
}

// Ask git which paths under the tree root it ignores, and why. Fills the
// external fw__tr_ign: path -> (rule, source, line), with folders as path/.
// specs are pathspecs relative to the tree root, or none. base is the tree
// root relative to the project root. Returns 0 when git cannot answer.
real scalar fw__tr_git(string scalar treeroot, string rowvector specs, string scalar base)
{
    external transmorphic scalar fw__tr_ign
    d = fw_scratch()
    g = fw__tr_gitcmd(d)
    if (g == "") {
        fw_scratch_done(d)
        return(0)
    }
    g = g + " -C " + fw__cliarg(treeroot)
    if (fw_run(g + " rev-parse --show-prefix", d, 60)) {
        fw_scratch_done(d)
        return(0)
    }
    treepre = fw_clean(fw_run_out(d))
    projpre = ""
    if (base == "") projpre = treepre
    else if (fw_endswith(treepre, base + "/")) projpre = substr(treepre, 1, strlen(treepre) - strlen(base) - 1)
    ps = ""
    if (cols(specs)) {
        ps = " --"
        for (i = 1; i <= cols(specs); i++) ps = ps + " " + fw__cliarg(specs[i])
    }
    if (fw_run(g + " ls-files --others --ignored --exclude-standard --directory -z" + ps, d, 300)) {
        fw_scratch_done(d)
        return(0)
    }
    list = d + "/ignored.bin"
    fw_copy(d + "/stdout.txt", list)
    fw__tr_ign = asarray_create()
    if (fw_filesize(list) == 0) {
        fw_scratch_done(d)
        return(1)
    }
    listarg = (fw_windows() ? fw_dq() + subinstr(list, "/", char(92)) + fw_dq() : fw_shq(list))
    rc = fw_run(g + " check-ignore -v -z --stdin < " + listarg, d, 300)
    // check-ignore exits 1 when it matches nothing.
    if (rc != 0 & rc != 1) {
        fw_scratch_done(d)
        return(0)
    }
    f = fw__tr_split0(fw_run_out(d))
    fw_scratch_done(d)
    for (i = 1; i + 3 <= rows(f); i = i + 4) {
        rule = f[i + 2]
        // A path that a ! pattern matches last is not ignored.
        if (substr(rule, 1, 1) == "!") continue
        asarray(fw__tr_ign, f[i + 3], (rule, fw__tr_source(f[i], treepre, projpre), f[i + 1]))
    }
    return(1)
}

// Symbolic links under the tree root, relative to it, in the external
// fw__tr_links. They publish as files and are never followed. Windows
// skips the search.
void fw__tr_find_links(string scalar treeroot)
{
    external transmorphic scalar fw__tr_links
    fw__tr_links = asarray_create()
    if (fw_windows()) return
    d = fw_scratch()
    rc = fw_run("cd " + fw_shq(treeroot) + " && find . -name .git -prune -o -type l -print0", d, 300)
    if (!rc) {
        f = fw__tr_split0(fw_run_out(d))
        for (i = 1; i <= rows(f); i++) {
            p = f[i]
            if (fw_startswith(p, "./")) p = substr(p, 3, .)
            if (p != "") asarray(fw__tr_links, p, 1)
        }
    }
    fw_scratch_done(d)
}

// ---------------------------------------------------------------------------
// The walk
// ---------------------------------------------------------------------------

// Why a path is ignored, as (rule, source, line), or J(1, 0, "").
string rowvector fw__tr_ignored(string scalar p, real scalar isdir)
{
    external transmorphic scalar fw__tr_ign
    external string matrix fw__tr_gi
    external string scalar fw__tr_method, fw__tr_giprefix
    if (fw__tr_method == "git") {
        key = p + (isdir ? "/" : "")
        if (asarray_contains(fw__tr_ign, key)) return(asarray(fw__tr_ign, key))
        return(J(1, 0, ""))
    }
    if (fw__tr_method == "gitignore") {
        k = fw_tree_match(fw__tr_gi, fw__tr_giprefix + p, isdir)
        if (k) return((fw__tr_gi[k, 4], ".gitignore", fw__tr_gi[k, 5]))
    }
    return(J(1, 0, ""))
}

real scalar fw__tr_excluded(string scalar p, real scalar isdir)
{
    external string matrix fw__tr_ex
    return(rows(fw__tr_ex) ? fw_tree_match(fw__tr_ex, p, isdir) > 0 : 0)
}

// A private folder: named private or ending in _private, in any case, or a
// settings folder marked private (a directories key with "private" and not
// "public"), or a folder under one.
real scalar fw__tr_private(string scalar abs, string scalar name)
{
    external string colvector fw__tr_privdirs
    low = ustrlower(name)
    if (low == "private" | fw_endswith(low, "_private")) return(1)
    a = ustrlower(fw_norm(abs))
    for (i = 1; i <= rows(fw__tr_privdirs); i++) {
        if (a == fw__tr_privdirs[i] | fw_startswith(a, fw__tr_privdirs[i] + "/")) return(1)
    }
    return(0)
}

// The settings folders marked private, as lowercase absolute paths.
string colvector fw__tr_settings_private()
{
    out = J(0, 1, "")
    p = findexternal("fw_settings")
    if (p == NULL) return(out)
    D = fw_directories(*p)
    for (i = 1; i <= rows(D); i++) {
        k = ustrlower(D[i, 1])
        if (strpos(k, "private") & !strpos(k, "public")) out = out \ ustrlower(fw_norm(D[i, 2]))
    }
    return(out)
}

// A folder's entries: names of its folders and files, with symbolic links
// as files and .git left out.
void fw__tr_list(string scalar abs, string scalar rel, string colvector dirs, string colvector files)
{
    external transmorphic scalar fw__tr_links
    dd = dir(abs, "dirs", "*", 0)
    ff = dir(abs, "files", "*", 0)
    dirs = J(0, 1, "")
    files = J(0, 1, "")
    for (i = 1; i <= rows(dd); i++) {
        if (dd[i] == "." | dd[i] == ".." | dd[i] == ".git") continue
        p = (rel == "" ? dd[i] : rel + "/" + dd[i])
        if (asarray_contains(fw__tr_links, p)) files = files \ dd[i]
        else dirs = dirs \ dd[i]
    }
    for (i = 1; i <= rows(ff); i++) if (ff[i] != ".git") files = files \ ff[i]
    // A broken link is no file to dir(), but find lists it.
    keys = asarray_keys(fw__tr_links)
    for (i = 1; i <= rows(keys); i++) {
        if (fw_dirname(keys[i]) == rel | (rel == "" & !strpos(keys[i], "/"))) {
            b = fw_basename(keys[i])
            if (!anyof(files, b)) files = files \ b
        }
    }
    if (rows(dirs)) dirs = dirs[order(ustrlower(dirs), 1)]
    if (rows(files)) files = files[order(ustrlower(files), 1)]
}

// Count the files under a folder, up to the cap. n carries the count.
void fw__tr_count(string scalar abs, string scalar rel, real scalar n)
{
    dirs = J(0, 1, "")
    files = J(0, 1, "")
    if (n >= fw__tr_cap()) return
    fw__tr_list(abs, rel, dirs, files)
    for (i = 1; i <= rows(files) & n < fw__tr_cap(); i++) {
        if (!fw__tr_excluded(rel + "/" + files[i], 0)) n++
    }
    for (i = 1; i <= rows(dirs) & n < fw__tr_cap(); i++) {
        p = rel + "/" + dirs[i]
        if (!fw__tr_excluded(p, 1)) fw__tr_count(abs + "/" + dirs[i], p, n)
    }
}

real scalar fw__tr_hidden(string scalar abs, string scalar rel)
{
    n = 0
    fw__tr_count(abs, rel, n)
    return(n)
}

// One folder entry as a row: a stub when private, ignored, or at the depth
// limit, else a listed folder. Returns J(0, 10, "") when it is left out.
// level is the folder's level below the tree root, starting at 1.
string matrix fw__tr_dirrow(string scalar abs, string scalar p, real scalar level, real scalar descend)
{
    external real scalar fw__tr_depth, fw__tr_hide
    name = fw_basename(p)
    if (fw__tr_excluded(p, 1)) return(J(0, fw__tr_cols(), ""))
    ig = fw__tr_ignored(p, 1)
    isig = (cols(ig) > 0)
    if (!isig) ig = ("", "", "")
    if (fw__tr_private(abs, name)) {
        if (isig & fw__tr_hide) return(J(0, fw__tr_cols(), ""))
        return((name, p, "dir", "1", (isig ? "1" : ""), "", ig, strofreal(fw__tr_hidden(abs, p))))
    }
    if (isig) {
        if (fw__tr_hide) return(J(0, fw__tr_cols(), ""))
        return((name, p, "dir", "", "1", "", ig, strofreal(fw__tr_hidden(abs, p))))
    }
    // Paths go 32 levels deep at most.
    if (level >= fw__tr_depth | level >= 32) {
        return((name, p, "dir", "", "", "1", "", "", "", strofreal(fw__tr_hidden(abs, p))))
    }
    if (descend) fw__tr_walk(abs, p, level + 1)
    return((name, p, "dir", "", "", "", "", "", "", ""))
}

// List a folder into fw__tr_kids, and its folders below it.
void fw__tr_walk(string scalar abs, string scalar rel, real scalar level)
{
    external transmorphic scalar fw__tr_kids
    external real scalar fw__tr_hide
    dirs = J(0, 1, "")
    files = J(0, 1, "")
    fw__tr_list(abs, rel, dirs, files)
    D = J(0, fw__tr_cols(), "")
    F = J(0, fw__tr_cols(), "")
    G = J(0, fw__tr_cols(), "")
    for (i = 1; i <= rows(dirs); i++) {
        p = (rel == "" ? dirs[i] : rel + "/" + dirs[i])
        D = D \ fw__tr_dirrow(abs + "/" + dirs[i], p, level, 1)
    }
    for (i = 1; i <= rows(files); i++) {
        p = (rel == "" ? files[i] : rel + "/" + files[i])
        if (fw__tr_excluded(p, 0)) continue
        ig = fw__tr_ignored(p, 0)
        if (cols(ig)) {
            if (!fw__tr_hide) G = G \ (files[i], p, "ignfile", "", "1", "", ig, "")
        }
        else F = F \ (files[i], p, "file", "", "", "", "", "", "", "")
    }
    fw__tr_addkids(rel, D \ F \ G)
}

// Add rows to a folder's entries.
void fw__tr_addkids(string scalar rel, string matrix rows_)
{
    external transmorphic scalar fw__tr_kids
    if (asarray_contains(fw__tr_kids, rel)) asarray(fw__tr_kids, rel, asarray(fw__tr_kids, rel) \ rows_)
    else asarray(fw__tr_kids, rel, rows_)
}

// Build the tree. paths are folders relative to the project root (none for
// the root). Sets the externals the printers and the writer read, and the
// locals fw_tree_root, fw_tree_base, fw_tree_method, and fw_tree_rootpath.
// depth is missing for no limit. hide leaves ignored paths out.
void fw_tree_build(string scalar paths_in, real scalar depth, string scalar exclude, real scalar hide)
{
    external transmorphic scalar fw__tr_kids, fw__tr_ign, fw__tr_links
    external string matrix fw__tr_gi, fw__tr_ex
    external string scalar fw__tr_method, fw__tr_giprefix
    external string colvector fw__tr_privdirs
    external real scalar fw__tr_depth, fw__tr_hide
    S = fw_S()
    proot = fw_norm(asarray(S, "__root"))
    fw__tr_kids = asarray_create()
    fw__tr_ign = asarray_create()
    fw__tr_depth = (depth >= . ? . : depth)
    fw__tr_hide = hide
    fw__tr_privdirs = fw__tr_settings_private()
    fw__tr_ex = J(0, 5, "")
    ex = tokens(exclude)
    for (i = 1; i <= cols(ex); i++) {
        P = fw__tr_pattern(ex[i], i)
        if (rows(P)) {
            if (P[1, 3] == "1") fw_error("fw_structure: exclude() takes globs to leave out, not ! patterns.", 198)
            fw__tr_ex = fw__tr_ex \ P
        }
    }

    // The chosen folders, relative to the project root.
    t = tokens(paths_in)
    rels = J(1, 0, "")
    for (i = 1; i <= cols(t); i++) {
        a = fw_abs(t[i], proot)
        if (!direxists(a)) fw_error("fw_structure: " + t[i] + " is not a folder in the project.", 601)
        if (a != proot & !fw_startswith(a, proot + "/")) fw_error("fw_structure: " + t[i] + " is outside the project root, " + proot + ".", 198)
        r = (a == proot ? "" : substr(a, strlen(proot) + 2, .))
        if (!anyof(rels, r)) rels = rels, r
    }
    if (cols(rels) == 0) rels = ""
    if (cols(rels) > 1 & anyof(rels, "")) rels = ""
    for (i = 1; i <= cols(rels); i++) {
        for (j = 1; j <= cols(rels); j++) {
            if (i != j & fw_startswith(rels[i], rels[j] + "/")) {
                fw_error("fw_structure: " + rels[i] + " is inside " + rels[j] + ". Give one or the other.", 198)
            }
        }
    }
    multi = (cols(rels) > 1)
    if (multi) {
        treeroot = proot
        base = ""
        specs = rels
    }
    else {
        treeroot = (rels[1] == "" ? proot : proot + "/" + rels[1])
        base = rels[1]
        specs = J(1, 0, "")
    }

    // Git decides what is ignored. Without it, the root .gitignore does.
    fw__tr_gi = J(0, 5, "")
    fw__tr_giprefix = (base == "" ? "" : base + "/")
    if (fw__tr_git(treeroot, specs, base)) fw__tr_method = "git"
    else if (fileexists(proot + "/.gitignore")) {
        fw__tr_method = "gitignore"
        fw__tr_gi = fw_tree_gitignore(proot + "/.gitignore")
    }
    else fw__tr_method = "none"
    fw__tr_find_links(treeroot)

    if (!multi) fw__tr_walk(treeroot, "", 1)
    else {
        fw__tr_addkids("", J(0, fw__tr_cols(), ""))
        rels = sort(rels', 1)'
        for (i = 1; i <= cols(rels); i++) {
            // The folders above a chosen folder are listed with only it.
            parts = tokens(rels[i], "/")
            parts = select(parts, parts :!= "/")
            up = ""
            for (k = 1; k < cols(parts); k++) {
                p = (up == "" ? parts[k] : up + "/" + parts[k])
                have = asarray(fw__tr_kids, up)
                if (!rows(have) | !anyof(have[., 2], p)) fw__tr_addkids(up, (parts[k], p, "dir", "", "", "", "", "", "", ""))
                if (!asarray_contains(fw__tr_kids, p)) fw__tr_addkids(p, J(0, fw__tr_cols(), ""))
                up = p
            }
            // Depth counts from the chosen folder.
            row = fw__tr_dirrow(proot + "/" + rels[i], rels[i], 0, 0)
            if (rows(row)) {
                fw__tr_addkids(up, row)
                if (row[1, 10] == "") fw__tr_walk(proot + "/" + rels[i], rels[i], 1)
            }
        }
        fw__tr_sortkids()
    }
    // A chosen folder that is private, or inside a private folder.
    priv = 0
    if (!multi & base != "") {
        parts = tokens(base, "/")
        parts = select(parts, parts :!= "/")
        up = proot
        for (k = 1; k <= cols(parts); k++) {
            up = up + "/" + parts[k]
            if (fw__tr_private(up, parts[k])) priv = 1
        }
    }
    st_local("fw_tree_private", strofreal(priv))
    st_local("fw_tree_root", fw_basename(multi | base == "" ? proot : treeroot))
    st_local("fw_tree_base", base)
    st_local("fw_tree_method", fw__tr_method)
    st_local("fw_tree_rootpath", treeroot)
}

// Folders first, then files, then ignored files, each by name.
void fw__tr_sortkids()
{
    external transmorphic scalar fw__tr_kids
    keys = asarray_keys(fw__tr_kids)
    for (i = 1; i <= rows(keys); i++) {
        K = asarray(fw__tr_kids, keys[i])
        if (rows(K) < 2) continue
        rank = (K[., 3] :== "dir") :* 1 + (K[., 3] :== "file") :* 2 + (K[., 3] :== "ignfile") :* 3
        o = order((strofreal(rank) :+ ustrlower(K[., 1])), 1)
        asarray(fw__tr_kids, keys[i], K[o, .])
    }
}

// ---------------------------------------------------------------------------
// Published nodes
// ---------------------------------------------------------------------------

// A folder's ignored files as groups by rule: rows of (rule, source, line,
// count, first index), in the order of the rule's first file.
string matrix fw__tr_groups(string matrix K)
{
    G = J(0, 5, "")
    for (i = 1; i <= rows(K); i++) {
        if (K[i, 3] != "ignfile") continue
        k = (rows(G) ? select(1::rows(G), G[., 1] :== K[i, 7] :& G[., 2] :== K[i, 8]) : J(0, 1, .))
        if (rows(k)) G[k[1], 4] = strofreal(strtoreal(G[k[1], 4]) + 1)
        else G = G \ (K[i, 7], K[i, 8], K[i, 9], "1", strofreal(i))
    }
    if (rows(G) > 1) G = G[order(ustrlower(G[., 1]), 1), .]
    return(G)
}

// The paths a note, open, or highlight can name: listed and stub folders
// and listed files.
string colvector fw__tr_paths()
{
    external transmorphic scalar fw__tr_kids
    out = J(0, 1, "")
    keys = asarray_keys(fw__tr_kids)
    for (i = 1; i <= rows(keys); i++) {
        K = asarray(fw__tr_kids, keys[i])
        for (j = 1; j <= rows(K); j++) if (K[j, 3] != "ignfile") out = out \ K[j, 2]
    }
    return(out)
}

// Read notes(), open(), and highlight() into the externals fw__tr_notes
// (path -> note), fw__tr_open, and fw__tr_hl, checking each path.
void fw_tree_marks(string scalar notes, string scalar open, string scalar highlight)
{
    external transmorphic scalar fw__tr_notes
    external string colvector fw__tr_open, fw__tr_hl
    have = fw__tr_paths()
    fw__tr_notes = asarray_create()
    t = tokens(notes)
    if (mod(cols(t), 2)) fw_error("fw_structure: notes() takes pairs of a path and its note, such as notes(R " + fw_dq() + "Reusable functions" + fw_dq() + ").", 198)
    for (i = 1; i < cols(t); i = i + 2) {
        p = fw__tr_markpath(t[i], have, "notes")
        if (ustrlen(t[i + 1]) > 500) fw_error("fw_structure: the note on " + p + " is longer than 500 characters.", 198)
        asarray(fw__tr_notes, p, t[i + 1])
    }
    fw__tr_open = J(0, 1, "")
    t = tokens(open)
    for (i = 1; i <= cols(t); i++) fw__tr_open = fw__tr_open \ fw__tr_markpath(t[i], have, "open")
    fw__tr_hl = J(0, 1, "")
    t = tokens(highlight)
    for (i = 1; i <= cols(t); i++) fw__tr_hl = fw__tr_hl \ fw__tr_markpath(t[i], have, "highlight")
}

string scalar fw__tr_markpath(string scalar p_in, string colvector have, string scalar opt)
{
    p = subinstr(p_in, char(92), "/")
    if (fw_startswith(p, "./")) p = substr(p, 3, .)
    while (fw_endswith(p, "/") & strlen(p) > 1) p = substr(p, 1, strlen(p) - 1)
    if (!rows(have) | !anyof(have, p)) fw_error("fw_structure: " + opt + "() names " + p_in + ", which is not in the tree. Paths are relative to the folder the tree shows.", 198)
    return(p)
}

string scalar fw__tr_ignjson(string scalar rule, string scalar src, string scalar line)
{
    s = "{" + fw_json_str("rule") + ":" + fw_json_str(rule)
    if (src != "") s = s + "," + fw_json_str("source") + ":" + fw_json_str(src)
    if (strtoreal(line) < .) s = s + "," + fw_json_str("line") + ":" + line
    return(s + "}")
}

// The published nodes, one JSON object each.
string colvector fw__tr_nodes()
{
    external transmorphic scalar fw__tr_kids, fw__tr_notes
    out = J(0, 1, "")
    keys = sort(asarray_keys(fw__tr_kids), 1)
    for (i = 1; i <= rows(keys); i++) {
        K = asarray(fw__tr_kids, keys[i])
        for (j = 1; j <= rows(K); j++) {
            if (K[j, 3] == "ignfile") continue
            s = "{" + fw_json_str("path") + ":" + fw_json_str(K[j, 2]) + "," + fw_json_str("type") + ":" + fw_json_str(K[j, 3])
            if (asarray_contains(fw__tr_notes, K[j, 2])) s = s + "," + fw_json_str("note") + ":" + fw_json_str(asarray(fw__tr_notes, K[j, 2]))
            if (K[j, 5] == "1") s = s + "," + fw_json_str("ignored") + ":" + fw__tr_ignjson(K[j, 7], K[j, 8], K[j, 9])
            if (K[j, 4] == "1") s = s + "," + fw_json_str("private") + ":true"
            if (K[j, 6] == "1") s = s + "," + fw_json_str("depth") + ":true"
            if (K[j, 10] != "") s = s + "," + fw_json_str("hidden") + ":" + K[j, 10]
            out = out \ (s + "}")
        }
        G = fw__tr_groups(K)
        for (j = 1; j <= rows(G); j++) {
            out = out \ ("{" + fw_json_str("path") + ":" + fw_json_str(keys[i]) + "," + fw_json_str("type") + ":" + fw_json_str("ignored") + "," +
                fw_json_str("ignored") + ":" + fw__tr_ignjson(G[j, 1], G[j, 2], G[j, 3]) + "," + fw_json_str("hidden") + ":" + G[j, 4] + "}")
        }
    }
    return(out)
}

// Write the tree document. Sets local fw_tree_nodes. Stops when Framework
// Cloud would refuse the tree.
void fw_tree_write(string scalar path, string scalar root, string scalar base, string scalar method)
{
    external string colvector fw__tr_open, fw__tr_hl
    N = fw__tr_nodes()
    if (rows(N) > 5000) {
        fw_error("fw_structure: the tree has " + strtrim(strofreal(rows(N), "%15.0fc")) + " entries, and Framework Cloud takes at most 5,000." + fw_nl() +
            "Use depth() to list fewer levels, or exclude() to leave folders out.", 198)
    }
    P = fw__tr_paths()
    for (i = 1; i <= rows(P); i++) {
        if (strlen(P[i]) > 1024) fw_error("fw_structure: the path " + P[i] + " is longer than 1,024 characters.", 198)
    }
    s = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.artifact/v1") + "," +
        fw_json_str("kind") + ":" + fw_json_str("tree") + "," +
        fw_json_str("source") + ":{" + fw_json_str("language") + ":" + fw_json_str("stata") + "}," +
        fw_json_str("root") + ":" + fw_json_str(root) + "," +
        fw_json_str("base") + ":" + fw_json_str(base) + "," +
        fw_json_str("method") + ":" + fw_json_str(method) + "," +
        fw_json_str("nodes") + ":[" + (rows(N) ? invtokens(N', ",") : "") + "]"
    if (rows(fw__tr_open)) s = s + "," + fw_json_str("open") + ":[" + fw__tr_jsonlist(fw__tr_open) + "]"
    if (rows(fw__tr_hl)) s = s + "," + fw_json_str("highlight") + ":[" + fw__tr_jsonlist(fw__tr_hl) + "]"
    fw_writefile(path, s + "}" + fw_nl())
    st_local("fw_tree_nodes", strofreal(rows(N)))
}

string scalar fw__tr_jsonlist(string colvector x)
{
    s = ""
    for (i = 1; i <= rows(x); i++) s = s + (i > 1 ? "," : "") + fw_json_str(x[i])
    return(s)
}

// ---------------------------------------------------------------------------
// Printing
// ---------------------------------------------------------------------------

string scalar fw__tr_files(real scalar n)
{
    if (n >= fw__tr_cap()) return(strtrim(strofreal(fw__tr_cap(), "%15.0fc")) + "+ files")
    return(strtrim(strofreal(n, "%15.0fc")) + (n == 1 ? " file" : " files"))
}

string scalar fw__tr_why(string scalar rule, string scalar src, string scalar line)
{
    where = src
    if (where == "") where = "unknown"
    if (strtoreal(line) < .) where = where + ":" + line
    return("ignored by " + rule + " (" + where + ")")
}

// What a row says after its name: its note, then why it is a stub.
string scalar fw__tr_badge(string rowvector r)
{
    external transmorphic scalar fw__tr_notes
    b = ""
    if (r[4] == "1" & r[5] == "1") b = "private · " + fw__tr_why(r[7], r[8], r[9]) + " · " + fw__tr_files(strtoreal(r[10]))
    else if (r[4] == "1") b = "private · " + fw__tr_files(strtoreal(r[10]))
    else if (r[5] == "1" & r[3] == "dir") b = fw__tr_why(r[7], r[8], r[9]) + " · " + fw__tr_files(strtoreal(r[10]))
    else if (r[5] == "1") b = fw__tr_why(r[7], r[8], r[9])
    else if (r[6] == "1") b = fw__tr_files(strtoreal(r[10]))
    note = (asarray_contains(fw__tr_notes, r[2]) ? asarray(fw__tr_notes, r[2]) : "")
    note = subinstr(subinstr(note, char(10), " "), char(13), " ")
    if (note != "" & b != "") return(note + " · " + b)
    return(note + b)
}

// The rows a folder shows: in the local tree, ignored files by name, at
// most 20 per rule; as published, one group per rule. Each row is (label,
// badge, path of a listed folder or "").
string matrix fw__tr_view(string scalar rel, real scalar publish)
{
    external transmorphic scalar fw__tr_kids
    out = J(0, 3, "")
    if (!asarray_contains(fw__tr_kids, rel)) return(out)
    K = asarray(fw__tr_kids, rel)
    for (i = 1; i <= rows(K); i++) {
        if (K[i, 3] == "ignfile") continue
        isdir = (K[i, 3] == "dir")
        out = out \ (K[i, 1] + (isdir ? "/" : ""), fw__tr_badge(K[i, .]), (isdir & K[i, 10] == "" ? K[i, 2] : char(31)))
    }
    G = fw__tr_groups(K)
    for (g = 1; g <= rows(G); g++) {
        why = fw__tr_why(G[g, 1], G[g, 2], G[g, 3])
        name = G[g, 1]
        if (fw_endswith(name, "/")) name = substr(name, 1, strlen(name) - 1)
        if (publish) {
            out = out \ (name, why + " · " + fw__tr_files(strtoreal(G[g, 4])), char(31))
            continue
        }
        shown = 0
        for (i = 1; i <= rows(K); i++) {
            if (K[i, 3] != "ignfile" | K[i, 7] != G[g, 1] | K[i, 8] != G[g, 2]) continue
            shown++
            if (shown <= 20) out = out \ (K[i, 1], why, char(31))
        }
        if (shown > 20) out = out \ ("… " + strtrim(strofreal(shown - 20, "%15.0fc")) + " more", why, char(31))
    }
    return(out)
}

void fw__tr_lines(string scalar rel, string scalar prefix, real scalar publish, string matrix L)
{
    V = fw__tr_view(rel, publish)
    for (i = 1; i <= rows(V); i++) {
        last = (i == rows(V))
        L = L \ (prefix + (last ? "└── " : "├── ") + V[i, 1], V[i, 2])
        if (V[i, 3] != char(31)) fw__tr_lines(V[i, 3], prefix + (last ? "    " : "│   "), publish, L)
    }
}

// Print the tree. publish shows it as it publishes, with groups in place of
// ignored file names.
void fw_tree_show(string scalar root, real scalar publish)
{
    L = (root + "/", "")
    fw__tr_lines("", "", publish, L)
    w = 0
    for (i = 1; i <= rows(L); i++) if (L[i, 2] != "") w = max((w, ustrlen(L[i, 1])))
    w = min((w, 40)) + 2
    for (i = 1; i <= rows(L); i++) {
        s = L[i, 1]
        if (L[i, 2] != "") s = s + " " * max((2, w - ustrlen(s))) + L[i, 2]
        display(s, 1)
    }
}

end
