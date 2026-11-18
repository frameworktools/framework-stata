*! fw_estimates.mata: Stata estimation results as framework.artifact/v1 models
*! Loaded by _fw_init. Do not run directly.
*
* The output matches the model.json that R and Python publish: a
* coefficient table with term, estimate, std_error, statistic, p_value,
* conf_low, and conf_high, plus fit metrics under the same names.
* Estimates stay on the model scale; model.exponentiate tells readers to
* offer a ratio view.

version 14

mata:
mata set matastrict off

real scalar fw_e(string scalar name)
{
    x = st_numscalar("e(" + name + ")")
    return(rows(x) ? x : .)
}

string scalar fw_es(string scalar name) return(st_global("e(" + name + ")"))

// A metric as a JSON object.
string scalar fw__metric(string scalar name, string scalar value, | string scalar label)
{
    s = "{" + fw_json_str("name") + ":" + fw_json_str(name) + "," + fw_json_str("value") + ":" + value
    if (args() > 2 & label != "") s = s + "," + fw_json_str("label") + ":" + fw_json_str(label)
    return(s + "}")
}

void fw__addnum(string rowvector M, string scalar name, real scalar x)
{
    if (missing(x)) return
    M = M, fw__metric(name, fw_json_num(x))
}

void fw__addstr(string rowvector M, string scalar name, string scalar s, | string scalar label)
{
    if (s == "") return
    M = M, fw__metric(name, fw_json_str(s), args() > 3 ? label : "")
}

string scalar fw__columns(string rowvector names, string rowvector types)
{
    s = "["
    for (i = 1; i <= cols(names); i++) {
        s = s + (i > 1 ? "," : "") + "{" + fw_json_str("name") + ":" + fw_json_str(names[i]) + "," +
            fw_json_str("type") + ":" + fw_json_str(types[i]) + "}"
    }
    return(s + "]")
}

string scalar fw__table(string scalar title, string scalar role, string scalar columns,
    string rowvector rows)
{
    s = "{" + fw_json_str("title") + ":" + fw_json_str(title) + ","
    if (role != "") s = s + fw_json_str("role") + ":" + fw_json_str(role) + ","
    s = s + fw_json_str("columns") + ":" + columns + "," + fw_json_str("rows") + ":["
    s = s + invtokens(rows, ",") + "]," + fw_json_str("row_count") + ":" + strofreal(cols(rows)) + "}"
    return(s)
}

// Value of a named parameter in e(b), for both the eq:_cons and /name stripes.
real scalar fw__param(real rowvector b, string matrix cs, string scalar p)
{
    for (j = 1; j <= cols(b); j++) {
        if (cs[j, 1] == p | (cs[j, 1] == "/" & cs[j, 2] == p)) return(b[j])
    }
    return(.)
}

real scalar fw__param_prefix(real rowvector b, string matrix cs, string scalar p)
{
    for (j = 1; j <= cols(b); j++) {
        name = (cs[j, 1] == "/" ? cs[j, 2] : cs[j, 1])
        if (fw_startswith(name, p)) return(b[j])
    }
    return(.)
}

real scalar fw__is_re_param(string scalar eq, string scalar nm)
{
    p = (eq == "/" ? nm : eq)
    return(regexm(p, "^lns[0-9]+_[0-9]+_[0-9]+$") | regexm(p, "^atr[0-9]+_[0-9_]+$") | p == "lnsig_e")
}

string scalar fw__family(string scalar f_in)
{
    f = strlower(f_in)
    if (f == "gaussian") return("gaussian")
    if (f == "bernoulli" | f == "binomial") return("binomial")
    if (f == "poisson") return("poisson")
    if (strpos(f, "neg") & strpos(f, "binomial")) return("negative binomial")
    if (f == "gamma") return("gamma")
    if (f == "inverse gaussian") return("inverse gaussian")
    return(f)
}

string scalar fw__link(string scalar l_in)
{
    l = strlower(l_in)
    if (l == "identity") return("identity")
    if (l == "logit") return("logit")
    if (l == "probit") return("probit")
    if (l == "log") return("log")
    if (l == "complementary log-log" | l == "cloglog") return("cloglog")
    if (l == "log-log" | l == "loglog") return("loglog")
    if (l == "power(-1)" | l == "reciprocal") return("inverse")
    if (l == "power(-2)") return("1/mu^2")
    if (l == "odds power") return("odds power")
    return(l)
}

string scalar fw__exponentiate(string scalar family, string scalar link)
{
    if (link == "logit") return("Odds ratio")
    if (link == "log" & anyof(("poisson", "quasipoisson", "negative binomial", "generalized poisson"), family)) return("Rate ratio")
    return("")
}

// The model document for the current estimation results.
string scalar fw_model_json(real scalar level)
{
    cmd = fw_es("cmd")
    if (cmd == "") fw_error("No estimation results found. Run an estimation command, such as regress, first.", 301)
    b = st_matrix("e(b)")
    V = st_matrix("e(V)")
    if (cols(b) == 0 | rows(V) == 0) fw_error(cmd + " left no coefficient vector e(b) and variance matrix e(V) to publish.", 301)
    cs = st_matrixcolstripe("e(b)")
    k = cols(b)
    se = sqrt(diagonal(V))'
    df_r = fw_e("df_r")
    tdist = (df_r < . & df_r > 0)
    alpha = 1 - level / 100
    crit = tdist ? invttail(df_r, alpha / 2) : invnormal(1 - alpha / 2)
    depvar = tokens(fw_es("depvar"))
    response = cols(depvar) ? depvar[1] : ""

    // The main equation is the first that is not a free parameter.
    main = ""
    for (j = 1; j <= k; j++) {
        if (cs[j, 1] != "/" & !fw__is_re_param(cs[j, 1], cs[j, 2])) {
            main = cs[j, 1]
            break
        }
    }

    type = "other"
    family = ""
    link = ""
    M = J(1, 0, "")
    tables = J(1, 0, "")
    title = "Coefficients"
    known = 1

    if (cmd == "regress") {
        type = "linear"; family = "gaussian"; link = "identity"
    }
    else if (cmd == "logit" | cmd == "logistic") {
        type = "glm"; family = "binomial"; link = "logit"
    }
    else if (cmd == "probit") {
        type = "glm"; family = "binomial"; link = "probit"
    }
    else if (cmd == "poisson") {
        type = "glm"; family = "poisson"; link = "log"
    }
    else if (cmd == "nbreg") {
        type = "glm"; family = "negative binomial"; link = "log"
    }
    else if (cmd == "glm") {
        type = "glm"
        family = fw__family(fw_es("varfunct") != "" ? fw_es("varfunct") : fw_es("varfuncf"))
        link = fw__link(fw_es("linkt") != "" ? fw_es("linkt") : fw_es("linkf"))
    }
    else if (cmd == "mixed") {
        type = "mixed"; family = "gaussian"; link = "identity"
        title = "Fixed effects"
    }
    else if (cmd == "cox" | cmd == "stcox") {
        type = "survival"
        response = "_t"
    }
    else if (cmd == "ivregress") {
        type = "linear"; family = "gaussian"; link = "identity"
    }
    else known = 0

    // Coefficient rows. Ancillary parameters, such as tobit's variance or
    // ologit's cutpoints, go in their own table. nbreg's lnalpha and lndelta
    // become the alpha and delta metrics, as R and Python report theta.
    rowsj = J(1, 0, "")
    ancj = J(1, 0, "")
    termj = J(1, 0, .)
    for (j = 1; j <= k; j++) {
        eq = cs[j, 1]
        nm = cs[j, 2]
        if (b[j] == 0 & (se[j] == 0 | missing(se[j]))) continue
        if (fw__is_re_param(eq, nm)) continue
        if (cmd == "nbreg" & anyof(("lnalpha", "lndelta"), eq == "/" ? nm : eq)) continue
        if (cmd == "mixed" & eq != main) continue
        // Free parameters: the "/" equation, an equation such as var(e.y)
        // with only _cons (tobit in Stata 15 and newer), and tobit's sigma
        // equation in Stata 14.
        freeq = (nm == "_cons" & (regexm(eq, "^(var|cov|sd|corr)[(]") | (cmd == "tobit" & eq == "sigma")))
        if (eq == "/" | freeq) {
            ancj = ancj, fw__anc_row(eq == "/" ? "/" + nm : "/" + eq, b[j], se[j], crit)
            continue
        }
        term = (nm == "_cons" ? "(Intercept)" : nm)
        if (eq == "/") term = "/" + nm
        else if (eq != "" & eq != main) term = eq + ": " + term
        est = b[j]
        s = se[j]
        if (missing(s) | s <= 0) {
            stat = .; p = .; lo = .; hi = .
            if (s <= 0) s = .
        }
        else {
            stat = est / s
            p = tdist ? 2 * ttail(df_r, abs(stat)) : 2 * normal(-abs(stat))
            lo = est - crit * s
            hi = est + crit * s
        }
        rowsj = rowsj, "[" + fw_json_str(term) + "," + fw_json_num(est) + "," + fw_json_num(s) + "," +
            fw_json_num(stat) + "," + fw_json_num(p) + "," + fw_json_num(lo) + "," + fw_json_num(hi) + "]"
        if (nm != "_cons") termj = termj, j
    }
    coefcols = fw__columns(("term", "estimate", "std_error", "statistic", "p_value", "conf_low", "conf_high"),
        ("string", "number", "number", "number", "number", "number", "number"))
    tables = tables, fw__table(title, "coefficients", coefcols, rowsj)
    if (cols(ancj)) tables = tables, fw__table("Ancillary parameters", "parameters", coefcols, ancj)

    // Fit metrics, under the names R and Python use.
    N = fw_e("N")
    fw__addnum(M, "nobs", N)
    if (cmd == "regress") {
        fw__addnum(M, "df_model", fw_e("df_m"))
        fw__addnum(M, "df_resid", fw_e("df_r"))
        fw__addnum(M, "r.squared", fw_e("r2"))
        fw__addnum(M, "adj.r.squared", fw_e("r2_a"))
        fw__addnum(M, "sigma", fw_e("rmse"))
    }
    else if (anyof(("logit", "logistic", "probit", "poisson", "nbreg"), cmd)) {
        fw__addnum(M, "df_model", fw_e("df_m"))
        fw__addnum(M, "pseudo_rsquared", fw_e("r2_p"))
        fw__addnum(M, "llnull", fw_e("ll_0"))
        if (cmd == "nbreg") {
            fw__addnum(M, "alpha", fw_e("alpha"))
            x = fw__param(b, cs, "lndelta")
            fw__addnum(M, "delta", fw_e("delta") < . ? fw_e("delta") : exp(x))
        }
    }
    else if (cmd == "glm") {
        fw__addnum(M, "df_resid", fw_e("df"))
        fw__addnum(M, "deviance", fw_e("deviance"))
        fw__addnum(M, "dispersion", fw_e("dispers_p"))
    }
    else if (cmd == "mixed") {
        fw__mixed(b, cs, M, tables)
    }
    else if (cmd == "cox" | cmd == "stcox") {
        fw__addnum(M, "n_events", fw_e("N_fail"))
        fw__addnum(M, "df_model", fw_e("df_m"))
    }
    else if (cmd == "tobit") {
        // Stata 15 and newer estimate var(e.y); older releases estimate sigma.
        x = fw__param(b, cs, "var(e." + response + ")")
        fw__addnum(M, "sigma", x < . & x >= 0 ? sqrt(x) : fw__param(b, cs, "sigma"))
    }
    else if (cmd == "ivregress") {
        fw__addnum(M, "df_model", fw_e("df_m"))
        fw__addnum(M, "df_resid", fw_e("df_r"))
        fw__addnum(M, "r.squared", fw_e("r2"))
        fw__addnum(M, "adj.r.squared", fw_e("r2_a"))
        fw__addnum(M, "sigma", fw_e("rmse"))
        fw__addstr(M, "estimator", fw_es("estimator"), "Estimator")
        fw__addstr(M, "instrumented", fw_es("instd"), "Instrumented")
        fw__addstr(M, "instruments", fw_es("insts"), "Instruments")
    }
    ll = fw_e("ll")
    rank = fw_e("rank")
    if (ll < . & rank < . & N < . & N > 0) {
        fw__addnum(M, "aic", -2 * ll + 2 * rank)
        fw__addnum(M, "bic", -2 * ll + ln(N) * rank)
    }
    fw__addnum(M, "log_likelihood", ll)
    if (fw_e("converged") < .) M = M, fw__metric("converged", fw_json_bool(fw_e("converged")))
    vt = fw_es("vcetype")
    if (vt == "") vt = fw_es("vce")
    fw__addstr(M, "vcov_type", vt)
    fw__addnum(M, "confidence_level", level / 100)
    M = M, fw__metric("interval_method", fw_json_str(tdist ? "wald-t" : "wald-normal"))
    fw__addstr(M, "command", fw_es("cmdline"), "Command")

    // The model block.
    mb = "{" + fw_json_str("type") + ":" + fw_json_str(type)
    if (family != "") mb = mb + "," + fw_json_str("family") + ":" + fw_json_str(family)
    if (link != "") mb = mb + "," + fw_json_str("link") + ":" + fw_json_str(link)
    if (response != "") mb = mb + "," + fw_json_str("response") + ":" + fw_json_str(response)
    ex = (type == "survival" ? "Hazard ratio" : fw__exponentiate(family, link))
    if (ex != "") mb = mb + "," + fw_json_str("exponentiate") + ":" + fw_json_str(ex)
    mb = mb + "}"

    classes = fw_json_str(cmd)
    if (fw_es("cmd2") != "" & fw_es("cmd2") != cmd) classes = fw_json_str(fw_es("cmd2")) + "," + classes
    if (fw_es("prefix") != "") classes = fw_json_str(fw_es("prefix")) + "," + classes

    s = "{" + fw_json_str("schema") + ":" + fw_json_str("framework.artifact/v1") + "," +
        fw_json_str("kind") + ":" + fw_json_str("model") + "," +
        fw_json_str("source") + ":{" + fw_json_str("language") + ":" + fw_json_str("stata") + "," +
        fw_json_str("class") + ":[" + classes + "]}," +
        fw_json_str("model") + ":" + mb + "," +
        fw_json_str("tables") + ":[" + invtokens(tables, ",") + "]," +
        fw_json_str("metrics") + ":[" + invtokens(M, ",") + "]" +
        fw__model_variables(cmd, b, cs, main, termj) + "}"
    st_local("fw_known", strofreal(known))
    st_local("fw_cmd", cmd)
    return(s)
}

// ---------------------------------------------------------------------------
// Model variables: the variables behind the model and its coefficient terms,
// summarized over the estimation sample e(sample). Never raw rows.
// ---------------------------------------------------------------------------

// One factor of a coefficient name, such as mpg, c.mpg, 1.foreign, 0b.foreign,
// or L.gdp. Sets vname, level ("" for a continuous part), base (a b marker),
// and omitted (an o marker). Returns 0 for a part it cannot read.
real scalar fw__term_part(string scalar part, string scalar vname, string scalar level,
    real scalar base, real scalar omitted)
{
    vname = ""; level = ""; base = 0; omitted = 0
    vals = J(0, 1, .); counts = J(0, 1, .)
    t = tokens(part, ".")
    if (cols(t) == 0) return(0)
    vname = t[cols(t)]
    if (vname == "." | !st_isname(vname)) return(0)
    for (i = 1; i < cols(t); i++) {
        op = t[i]
        if (op == ".") continue
        if (regexm(op, "^([0-9]+)([bno]*)$")) {
            if (level != "") return(0)
            level = regexs(1)
            flags = regexs(2)
            base = (strpos(flags, "b") & !strpos(flags, "n"))
            if (strpos(flags, "o")) omitted = 1
        }
        else if (op == "c" | op == "co") {
            if (op == "co") omitted = 1
        }
        else if (op == "o") omitted = 1
        // Time-series operators map to the variable they act on.
        else if (!regexm(op, "^([LFDS][0-9]*)+$")) return(0)
    }
    return(1)
}

// A value as text: its value label when it has one, else the number.
string scalar fw__level_text(string scalar vname, real scalar x)
{
    lab = st_varvaluelabel(vname)
    if (lab != "") {
        if (st_vlexists(lab)) {
            s = st_vlmap(lab, x)
            if (s != "") return(s)
        }
    }
    return(fw_json_num(x))
}

// Add a variable once, keeping its first role. fac marks a factor variable.
void fw__var_add(string rowvector names, string rowvector roles, real rowvector facs,
    string scalar vname, string scalar role, real scalar fac)
{
    for (i = 1; i <= cols(names); i++) {
        if (names[i] == vname) {
            facs[i] = facs[i] | fac
            return
        }
    }
    names = names, vname
    roles = roles, role
    facs = facs, fac
}

// Linear-interpolation quantile of sorted values, as table summaries use.
real scalar fw__quantile(real colvector s, real scalar p)
{
    n = rows(s)
    h = (n - 1) * p
    lo = floor(h)
    hi = min((lo + 1, n - 1))
    return(s[lo + 1] + (h - lo) * (s[hi + 1] - s[lo + 1]))
}

// A summary number. A float variable holds about seven significant digits,
// so its values print with no more than that.
string scalar fw__summary_num(real scalar x, real scalar isfloat)
{
    if (!isfloat | missing(x) | x == floor(x)) return(fw_json_num(x))
    s = strtrim(strofreal(x, "%15.7g"))
    if (fw_startswith(s, ".")) s = "0" + s
    if (fw_startswith(s, "-.")) s = "-0" + substr(s, 2, .)
    return(s)
}

// The summary object for one variable over the sample. For a categorical
// variable, vals and counts return its distinct values and their counts.
string scalar fw__var_summary(string scalar vname, string scalar touse, real scalar categorical,
    real colvector vals, real colvector counts)
{
    x = st_data(., vname, touse)
    n = rows(x)
    present = select(x, x :< .)
    m = rows(present)
    vals = J(0, 1, .)
    counts = J(0, 1, .)
    if (m) {
        srt = sort(present, 1)
        starts = 1
        if (m > 1) starts = 1 \ select((2::m), srt[|2 \ m|] :!= srt[|1 \ m - 1|])
        vals = srt[starts]
        k = rows(starts)
        ends = m + 1
        if (k > 1) ends = starts[|2 \ k|] \ m + 1
        counts = ends - starts
    }
    k = rows(vals)
    s = "{" + fw_json_str("count") + ":" + fw_json_num(n) + "," + fw_json_str("missing") + ":" + fw_json_num(n - m) +
        "," + fw_json_str("distinct") + ":" + fw_json_num(k)
    if (!m) return(s + "}")
    if (!categorical) {
        fl = (st_vartype(vname) == "float")
        s = s + "," + fw_json_str("mean") + ":" + fw__summary_num(mean(srt), fl)
        if (m > 1) s = s + "," + fw_json_str("sd") + ":" + fw__summary_num(sqrt(variance(srt)), fl)
        s = s + "," + fw_json_str("min") + ":" + fw__summary_num(srt[1], fl) +
            "," + fw_json_str("q1") + ":" + fw__summary_num(fw__quantile(srt, .25), fl) +
            "," + fw_json_str("median") + ":" + fw__summary_num(fw__quantile(srt, .5), fl) +
            "," + fw_json_str("q3") + ":" + fw__summary_num(fw__quantile(srt, .75), fl) +
            "," + fw_json_str("max") + ":" + fw__summary_num(srt[m], fl)
        return(s + "}")
    }
    // The most common values, at most 8, when some value repeats.
    if (k < m | m == 1) {
        o = order((-counts, (1::k)), (1, 2))
        top = J(1, 0, "")
        for (i = 1; i <= min((8, k)); i++) {
            top = top, "{" + fw_json_str("value") + ":" + fw_json_str(fw__level_text(vname, vals[o[i]])) + "," +
                fw_json_str("count") + ":" + fw_json_num(counts[o[i]]) + "}"
        }
        s = s + "," + fw_json_str("top") + ":[" + invtokens(top, ",") + "]"
    }
    return(s + "}")
}

// The "variables" and "terms" fields, with a leading comma, or "" when the
// estimation sample is unavailable, such as after estimates use.
string scalar fw__model_variables(string scalar cmd, real rowvector b, string matrix cs,
    string scalar main, real rowvector termj)
{
    if (st_nobs() == 0) return("")
    names = J(1, 0, ""); roles = J(1, 0, ""); facs = J(1, 0, .)
    vname = ""; level = ""; base = 0; omitted = 0
    vals = J(0, 1, .); counts = J(0, 1, .)
    bases = J(1, 0, ""); basevars = J(1, 0, "")

    // Responses first; D.y maps to y.
    dv = tokens(fw_es("depvar"))
    for (i = 1; i <= cols(dv); i++) {
        if (!fw__term_part(dv[i], vname, level, base, omitted) | level != "") continue
        fw__var_add(names, roles, facs, vname, "response", 0)
    }

    // Base levels, from the b markers on any coefficient, main effects first.
    for (pass = 1; pass <= 2; pass++) {
        for (j = 1; j <= cols(b); j++) {
            eq = cs[j, 1]
            if (eq == "/" | fw__is_re_param(eq, cs[j, 2])) continue
            pr = tokens(cs[j, 2], "#")
            pr = select(pr, pr :!= "#")
            if ((pass == 1) != (cols(pr) == 1)) continue
            for (q = 1; q <= cols(pr); q++) {
                if (!fw__term_part(pr[q], vname, level, base, omitted)) continue
                if (!base | anyof(basevars, vname)) continue
                basevars = basevars, vname
                bases = bases, level
            }
        }
    }

    // Predictors and terms, from the coefficient table's own rows.
    // Each term's parts as "variable:level" words; level is digits or empty.
    tterm = J(1, 0, ""); tparts = J(1, 0, "")
    for (t = 1; t <= cols(termj); t++) {
        j = termj[t]
        eq = cs[j, 1]
        nm = cs[j, 2]
        term = ((eq != "" & eq != main) ? eq + ": " + nm : nm)
        pr = tokens(nm, "#")
        pr = select(pr, pr :!= "#")
        if (cols(pr) == 0 | cols(pr) > 10) continue
        pv = J(1, cols(pr), ""); pl = J(1, cols(pr), "")
        ok = 1
        for (q = 1; q <= cols(pr); q++) {
            if (!fw__term_part(pr[q], vname, level, base, omitted)) {
                ok = 0
                break
            }
            pv[q] = vname
            pl[q] = vname + ":" + level
        }
        if (!ok) continue
        for (q = 1; q <= cols(pr); q++) {
            fw__var_add(names, roles, facs, pv[q], "predictor", !fw_endswith(pl[q], ":"))
        }
        tterm = tterm, term
        tparts = tparts, invtokens(pl, " ")
    }

    // Grouping factors of multilevel models, then weights and offsets.
    if (cmd == "mixed" | fw_startswith(cmd, "me")) {
        iv = tokens(fw_es("ivars"))
        for (i = 1; i <= cols(iv); i++) {
            if (iv[i] != "_all" & st_isname(iv[i])) fw__var_add(names, roles, facs, iv[i], "group", 1)
        }
    }
    w = strtrim(subinstr(fw_es("wexp"), "=", "", 1))
    if (st_isname(w)) fw__var_add(names, roles, facs, w, "weight", 0)
    off = strtrim(fw_es("offset"))
    if (regexm(off, "^ln[(](.+)[)]$")) off = strtrim(regexs(1))
    if (off != "" & st_isname(off)) fw__var_add(names, roles, facs, off, "offset", 0)

    if (cols(names) == 0) return("")
    touse = st_tempname()
    if (_stata("quietly generate byte " + touse + " = e(sample)", 1)) return("")
    nsample = sum(st_data(., touse))
    if (nsample == 0) {
        st_dropvar(touse)
        return("")
    }

    V = J(1, 0, "")
    kept = J(1, 0, "")
    for (i = 1; i <= cols(names); i++) {
        if (cols(V) == 100) break
        vname = names[i]
        if (_st_varindex(vname) >= .) continue
        if (!st_isnumvar(vname)) continue
        role = roles[i]
        // A response is categorical when value-labeled or modeled as categories.
        cat = facs[i] | role == "group" | (role == "response" & (st_varvaluelabel(vname) != "" |
            anyof(("mlogit", "ologit", "oprobit", "mprobit"), cmd)))
        summ = fw__var_summary(vname, touse, cat, vals, counts)
        s = "{" + fw_json_str("name") + ":" + fw_json_str(vname) + "," + fw_json_str("role") + ":" + fw_json_str(role) +
            "," + fw_json_str("type") + ":" + fw_json_str(cat ? "categorical" : "number")
        lab = st_varlabel(vname)
        if (lab != "") s = s + "," + fw_json_str("label") + ":" + fw_json_str(lab)
        if (cat & role != "group" & rows(vals)) {
            lv = J(1, min((50, rows(vals))), "")
            for (l = 1; l <= cols(lv); l++) lv[l] = fw_json_str(fw__level_text(vname, vals[l]))
            s = s + "," + fw_json_str("levels") + ":[" + invtokens(lv, ",") + "]"
        }
        if (cat & role == "predictor") {
            for (l = 1; l <= cols(basevars); l++) {
                if (basevars[l] == vname) {
                    s = s + "," + fw_json_str("reference") + ":" + fw_json_str(fw__level_text(vname, strtoreal(bases[l])))
                    break
                }
            }
        }
        V = V, s + "," + fw_json_str("summary") + ":" + summ + "}"
        kept = kept, vname
    }
    st_dropvar(touse)
    if (cols(V) == 0) return("")

    // Terms whose variables are all listed, at most 500.
    T = J(1, 0, "")
    for (t = 1; t <= cols(tterm); t++) {
        if (cols(T) == 500) break
        pw = tokens(tparts[t])
        P = J(1, 0, "")
        for (q = 1; q <= cols(pw); q++) {
            c = strpos(pw[q], ":")
            vname = substr(pw[q], 1, c - 1)
            level = substr(pw[q], c + 1, .)
            if (!anyof(kept, vname)) break
            p = "{" + fw_json_str("variable") + ":" + fw_json_str(vname)
            if (level != "") p = p + "," + fw_json_str("level") + ":" + fw_json_str(fw__level_text(vname, strtoreal(level)))
            P = P, p + "}"
        }
        if (cols(P) < cols(pw)) continue
        T = T, "{" + fw_json_str("term") + ":" + fw_json_str(tterm[t]) + "," + fw_json_str("parts") + ":[" + invtokens(P, ",") + "]}"
    }
    s = "," + fw_json_str("variables") + ":[" + invtokens(V, ",") + "]"
    if (cols(T)) s = s + "," + fw_json_str("terms") + ":[" + invtokens(T, ",") + "]"
    return(s)
}

// A row of the ancillary table. Stata reports no test for variances,
// covariances, correlations, cutpoints, and sigma, and gives variances, standard
// deviations, and correlations a transformed interval, as here.
string scalar fw__anc_row(string scalar term, real scalar est, real scalar s_in, real scalar crit)
{
    s = s_in
    stat = .; p = .; lo = .; hi = .
    nm = substr(term, 2, .)
    notest = (regexm(nm, "^(var|cov|sd|corr)[(]") | regexm(nm, "^cut[0-9]+$") | nm == "sigma")
    if (missing(s) | s <= 0) {
        if (s <= 0) s = .
    }
    else if ((fw_startswith(nm, "var(") | fw_startswith(nm, "sd(")) & est > 0) {
        lo = exp(ln(est) - crit * s / est)
        hi = exp(ln(est) + crit * s / est)
    }
    else if (fw_startswith(nm, "corr(") & abs(est) < 1) {
        lo = tanh(atanh(est) - crit * s / (1 - est^2))
        hi = tanh(atanh(est) + crit * s / (1 - est^2))
    }
    else {
        lo = est - crit * s
        hi = est + crit * s
    }
    if (!notest & s < .) {
        stat = est / s
        df_r = fw_e("df_r")
        p = (df_r < . & df_r > 0) ? 2 * ttail(df_r, abs(stat)) : 2 * normal(-abs(stat))
    }
    return("[" + fw_json_str(term) + "," + fw_json_num(est) + "," + fw_json_num(s) + "," +
        fw_json_num(stat) + "," + fw_json_num(p) + "," + fw_json_num(lo) + "," + fw_json_num(hi) + "]")
}

// Random effects for mixed: rebuilt from the log standard deviations and
// hyperbolic-arctangent correlations Stata estimates.
void fw__mixed(real rowvector b, string matrix cs, string rowvector M, string rowvector tables)
{
    ivars = tokens(fw_es("ivars"))
    revars = tokens(fw_es("revars"))
    vartypes = tokens(fw_es("vartypes"))
    // e(redim) is a macro in current Stata; older releases stored a matrix.
    redim = strtoreal(tokens(fw_es("redim")))
    if (cols(redim) == 0) redim = st_matrix("e(redim)")
    Ng = st_matrix("e(N_g)")
    L = cols(ivars)
    rows_re = J(1, 0, "")
    any_corr = 0
    ok = 1
    rs = fw_es("rstructure")
    if (rs != "" & strlower(rs) != "independent") ok = 0
    offset = 0
    for (l = 1; l <= L; l++) {
        dim = (cols(redim) >= l ? redim[l] : 1)
        vt = strlower(cols(vartypes) >= l ? vartypes[l] : "independent")
        comps = (offset + dim <= cols(revars) ? revars[|offset + 1 \ offset + dim|] : J(1, dim, "_cons"))
        offset = offset + dim
        g = ivars[l]
        if (cols(Ng) >= l) fw__addnum(M, "n_groups." + g, Ng[l])
        if (!anyof(("independent", "identity", "exchangeable", "unstructured"), vt)) {
            ok = 0
            continue
        }
        sds = J(1, dim, .)
        for (c = 1; c <= dim; c++) {
            // Stata names these lns<level>_1_<component>.
            name = "lns" + strofreal(l) + "_1_" + strofreal(vt == "identity" | vt == "exchangeable" ? 1 : c)
            x = fw__param(b, cs, name)
            sds[c] = exp(x)
            term = (comps[c] == "_cons" ? "(Intercept)" : comps[c])
            rows_re = rows_re, "[" + fw_json_str(g) + "," + fw_json_str(term) + "," +
                fw_json_num(exp(2 * x)) + "," + fw_json_num(exp(x)) + ",null]"
        }
        if (vt == "exchangeable" | vt == "unstructured") {
            for (c = 1; c <= dim; c++) {
                for (e = c + 1; e <= dim; e++) {
                    // atr<level>_1_<c>_<d>; exchangeable has one shared parameter.
                    if (vt == "exchangeable") x = fw__param_prefix(b, cs, "atr" + strofreal(l) + "_")
                    else x = fw__param(b, cs, "atr" + strofreal(l) + "_1_" + strofreal(c) + "_" + strofreal(e))
                    if (missing(x)) continue
                    t1 = (comps[c] == "_cons" ? "(Intercept)" : comps[c])
                    t2 = (comps[e] == "_cons" ? "(Intercept)" : comps[e])
                    rows_re = rows_re, "[" + fw_json_str(g) + "," + fw_json_str(t1 + ", " + t2) + ",null,null," +
                        fw_json_num(tanh(x)) + "]"
                    any_corr = 1
                }
            }
        }
    }
    x = fw__param(b, cs, "lnsig_e")
    if (!missing(x)) {
        rows_re = rows_re, "[" + fw_json_str("Residual") + "," + fw_json_str("") + "," +
            fw_json_num(exp(2 * x)) + "," + fw_json_num(exp(x)) + ",null]"
        fw__addnum(M, "sigma", exp(x))
    }
    M = M, fw__metric("reml", fw_json_bool(strupper(fw_es("method")) == "REML"))
    if (!ok) {
        printf("{txt}Note: this mixed model uses a covariance or residual structure that Framework does not convert yet. The fixed effects are published; the random-effects table is not.\n")
        return
    }
    if (!any_corr) {
        // Drop the all-null correlation column, as R and Python do.
        for (i = 1; i <= cols(rows_re); i++) rows_re[i] = substr(rows_re[i], 1, strlen(rows_re[i]) - 6) + "]"
        cols_re = fw__columns(("group", "term", "variance", "std_dev"), ("string", "string", "number", "number"))
    }
    else {
        cols_re = fw__columns(("group", "term", "variance", "std_dev", "correlation"),
            ("string", "string", "number", "number", "number"))
    }
    tables = tables, fw__table("Random effects", "random_effects", cols_re, rows_re)
}

end
