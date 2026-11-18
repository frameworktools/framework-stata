* Estimation results as framework.artifact/v1 model documents.

capture program drop t_model
program define t_model
    * Build the model document and parse it back. Leaves Mata matrix J.
    mata: s = fw_model_json(95)
    mata: J = fw_json_parse(s)
    mata: assert(fw_get(J, "schema") == "framework.artifact/v1")
    mata: assert(fw_get(J, "kind") == "model")
    mata: assert(fw_get(J, "source.language") == "stata")
end

capture program drop t_get
program define t_get, rclass
    mata: st_local("v", fw_get(J, st_local("0")))
    return local v `"`v'"'
end

* Find a metric value by name. Returns r(v).
mata:
string scalar t_metric_value(transmorphic J, string scalar name)
{
    n = strtoreal(fw_get(J, "metrics.#"))
    for (i = 0; i < n; i++) {
        if (fw_get(J, "metrics." + strofreal(i) + ".name") == name) return(fw_get(J, "metrics." + strofreal(i) + ".value"))
    }
    return("")
}
end

capture program drop t_metric
program define t_metric, rclass
    mata: st_local("v", t_metric_value(J, st_local("0")))
    return local v `"`v'"'
end

t_begin estimates: regress matches its own table
capture noisily {
    sysuse auto, clear
    regress price mpg weight i.foreign
    t_model
    t_get model.type
    t_eq "`r(v)'" "linear"
    t_get model.response
    t_eq "`r(v)'" "price"
    t_get tables.0.role
    t_eq "`r(v)'" "coefficients"
    * mpg row: estimate, se, t, p, ci
    matrix T = r(table)
    t_get tables.0.rows.0.0
    t_eq "`r(v)'" "mpg"
    t_get tables.0.rows.0.1
    assert reldif(real("`r(v)'"), _b[mpg]) < 1e-12
    t_get tables.0.rows.0.2
    assert reldif(real("`r(v)'"), _se[mpg]) < 1e-12
    quietly regress
    matrix T = r(table)
    t_get tables.0.rows.0.4
    assert reldif(real("`r(v)'"), T[4, 1]) < 1e-9
    t_get tables.0.rows.0.5
    assert reldif(real("`r(v)'"), T[5, 1]) < 1e-9
    * The base level 0.foreign is dropped; 1.foreign stays; _cons is renamed.
    t_get tables.0.row_count
    t_eq "`r(v)'" "4"
    t_get tables.0.rows.3.0
    t_eq "`r(v)'" "(Intercept)"
    t_metric r.squared
    assert reldif(real("`r(v)'"), e(r2)) < 1e-12
    t_metric interval_method
    t_eq "`r(v)'" "wald-t"
    t_metric nobs
    t_eq "`r(v)'" "74"
}
t_end `=_rc'

t_begin estimates: logit and logistic give odds ratios on the log scale
capture noisily {
    sysuse auto, clear
    logit foreign mpg weight
    local b = _b[mpg]
    t_model
    t_get model.exponentiate
    t_eq "`r(v)'" "Odds ratio"
    t_get model.link
    t_eq "`r(v)'" "logit"
    t_get tables.0.rows.0.1
    assert reldif(real("`r(v)'"), `b') < 1e-12
    t_metric interval_method
    t_eq "`r(v)'" "wald-normal"
    logistic foreign mpg weight
    t_model
    t_get tables.0.rows.0.1
    assert reldif(real("`r(v)'"), `b') < 1e-9
}
t_end `=_rc'

t_begin estimates: probit, poisson, nbreg
capture noisily {
    sysuse auto, clear
    probit foreign mpg
    t_model
    t_get model.link
    t_eq "`r(v)'" "probit"
    poisson rep78 mpg
    t_model
    t_get model.exponentiate
    t_eq "`r(v)'" "Rate ratio"
    nbreg rep78 mpg
    t_model
    t_get model.family
    t_eq "`r(v)'" "negative binomial"
    t_get tables.0.row_count
    t_eq "`r(v)'" "2"
    t_metric alpha
    assert reldif(real("`r(v)'"), e(alpha)) < 1e-9
}
t_end `=_rc'

t_begin estimates: glm families and links
capture noisily {
    sysuse auto, clear
    glm foreign mpg, family(binomial) link(logit)
    t_model
    t_get model.family
    t_eq "`r(v)'" "binomial"
    t_get model.exponentiate
    t_eq "`r(v)'" "Odds ratio"
    glm price mpg, family(gamma) link(log)
    t_model
    t_get model.family
    t_eq "`r(v)'" "gamma"
    t_get model.link
    t_eq "`r(v)'" "log"
    t_get model.exponentiate
    t_eq "`r(v)'" ""
}
t_end `=_rc'

t_begin estimates: mixed with random intercepts and slopes
capture noisily {
    clear
    set seed 20261105
    set obs 400
    gen school = ceil(_n / 20)
    gen x = rnormal()
    bysort school: gen u0 = rnormal() if _n == 1
    bysort school: replace u0 = u0[1]
    gen y = 1 + 0.5 * x + u0 + rnormal()
    mixed y x || school: x, covariance(unstructured)
    matrix list e(b)
    display "`e(revars)' | `e(vartypes)' | `e(ivars)'"
    t_model
    t_get model.type
    t_eq "`r(v)'" "mixed"
    t_get tables.0.title
    t_eq "`r(v)'" "Fixed effects"
    t_get tables.0.row_count
    t_eq "`r(v)'" "2"
    t_get tables.1.role
    t_eq "`r(v)'" "random_effects"
    * slope, intercept, correlation, residual
    t_get tables.1.row_count
    t_eq "`r(v)'" "4"
    t_get tables.1.rows.3.0
    t_eq "`r(v)'" "Residual"
    t_metric n_groups.school
    t_eq "`r(v)'" "20"
    t_metric reml
    t_eq "`r(v)'" `"`=cond("`e(method)'" == "REML", "true", "false")'"'
    * Compare with estat sd, which Stata 15 added.
    if c(stata_version) >= 15 estat sd
    mixed y x || school:, reml
    t_model
    t_metric reml
    t_eq "`r(v)'" "true"
    mixed y x || school: x, covariance(exchangeable)
    matrix list e(b)
    t_model
    t_get tables.1.row_count
    t_eq "`r(v)'" "4"
    mixed y x || school:, mle
    matrix list e(b)
    t_model
    t_get tables.1.row_count
    t_eq "`r(v)'" "2"
    t_get tables.1.rows.0.3
    local sd = real("`r(v)'")
    assert reldif(`sd', exp(_b[lns1_1_1:_cons])) < 1e-9
    t_metric reml
    t_eq "`r(v)'" "false"
}
t_end `=_rc'

t_begin estimates: stcox gives hazard ratios with no intercept
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox i.drug age
    t_model
    t_get model.type
    t_eq "`r(v)'" "survival"
    t_get model.exponentiate
    t_eq "`r(v)'" "Hazard ratio"
    t_metric n_events
    t_eq "`r(v)'" "31"
    t_get tables.0.row_count
    t_eq "`r(v)'" "3"
}
t_end `=_rc'

t_begin estimates: ivregress records instruments
capture noisily {
    sysuse auto, clear
    ivregress 2sls price weight (mpg = length turn)
    t_model
    t_metric instrumented
    t_eq "`r(v)'" "mpg"
    t_metric estimator
    t_eq "`r(v)'" "2sls"
    t_metric interval_method
    t_eq "`r(v)'" "wald-normal"
    ivregress 2sls price weight (mpg = length turn), small
    t_model
    t_metric interval_method
    t_eq "`r(v)'" "wald-t"
}
t_end `=_rc'

t_begin estimates: other commands publish a generic coefficient table
capture noisily {
    sysuse auto, clear
    qreg price mpg
    t_model
    t_get model.type
    t_eq "`r(v)'" "other"
    t_get tables.0.row_count
    t_eq "`r(v)'" "2"
}
t_end `=_rc'

* Whether any row of a table has the term. Returns r(v) 1 or 0.
mata:
real scalar t_has_term(transmorphic J, real scalar t, string scalar term)
{
    n = strtoreal(fw_get(J, "tables." + strofreal(t) + ".row_count"))
    for (i = 0; i < n; i++) {
        if (fw_get(J, "tables." + strofreal(t) + ".rows." + strofreal(i) + ".0") == term) return(1)
    }
    return(0)
}
end

t_begin estimates: nbreg dispersion(constant) reports delta, not a coefficient
capture noisily {
    sysuse auto, clear
    nbreg rep78 mpg, dispersion(constant)
    matrix list e(b)
    t_model
    mata: assert(!t_has_term(J, 0, "/lndelta") & !t_has_term(J, 0, "lndelta: (Intercept)"))
    t_get tables.0.row_count
    t_eq "`r(v)'" "2"
    t_get tables.#
    t_eq "`r(v)'" "1"
    t_metric delta
    assert reldif(real("`r(v)'"), exp(_b[/lndelta])) < 1e-9
    nbreg rep78 mpg
    t_model
    mata: assert(!t_has_term(J, 0, "/lnalpha"))
    t_metric alpha
    assert reldif(real("`r(v)'"), e(alpha)) < 1e-9
}
t_end `=_rc'

t_begin estimates: tobit's variance goes in the ancillary table without a test
capture noisily {
    sysuse auto, clear
    * Stata 15 and newer estimate var(e.mpg); version 14 estimates sigma.
    local versions 14
    if c(stata_version) >= 15 local versions `versions' 15
    if c(stata_version) >= 17 local versions `versions' 17
    foreach v of local versions {
        version `v': tobit mpg weight, ll(17)
        matrix T = r(table)
        matrix list e(b)
        local k = colsof(T)
        local term = cond(`v' == 14, "/sigma", "/var(e.mpg)")
        t_model
        mata: assert(!t_has_term(J, 0, st_local("term")))
        t_get tables.0.row_count
        t_eq "`r(v)'" "2"
        t_get tables.1.role
        t_eq "`r(v)'" "parameters"
        t_get tables.1.rows.0.0
        t_eq "`r(v)'" "`term'"
        t_get tables.1.rows.0.1
        assert reldif(real("`r(v)'"), T[1, `k']) < 1e-9
        * No test statistic or p-value, as Stata shows none.
        t_get tables.1.rows.0.3
        t_eq "`r(v)'" ""
        t_get tables.1.rows.0.4
        t_eq "`r(v)'" ""
        * The interval matches Stata's: log scale for a variance.
        t_get tables.1.rows.0.5
        assert reldif(real("`r(v)'"), T[5, `k']) < 1e-6
        t_get tables.1.rows.0.6
        assert reldif(real("`r(v)'"), T[6, `k']) < 1e-6
        t_metric sigma
        assert reldif(real("`r(v)'"), cond(`v' == 14, T[1, `k'], sqrt(T[1, `k']))) < 1e-9
    }
}
t_end `=_rc'

t_begin estimates: no results gives error 301
capture noisily {
    ereturn clear
    capture mata: fw_model_json(95)
    assert _rc == 301
}
t_end `=_rc'

t_begin estimates: variables and terms describe the estimation sample
capture noisily {
    sysuse auto, clear
    regress price c.mpg##i.foreign i.rep78
    t_model
    * Response, then predictors in coefficient order.
    t_get variables.#
    t_eq "`r(v)'" "4"
    t_get variables.0.name
    t_eq "`r(v)'" "price"
    t_get variables.0.role
    t_eq "`r(v)'" "response"
    t_get variables.0.type
    t_eq "`r(v)'" "number"
    t_get variables.0.label
    t_eq "`r(v)'" "Price"
    * Summaries cover e(sample): rep78 drops 5 cars.
    quietly summarize price if e(sample), detail
    local mean = r(mean)
    local sd = r(sd)
    local min = r(min)
    local max = r(max)
    t_get variables.0.summary.count
    t_eq "`r(v)'" "69"
    t_get variables.0.summary.missing
    t_eq "`r(v)'" "0"
    t_get variables.0.summary.mean
    assert reldif(real("`r(v)'"), `mean') < 1e-12
    t_get variables.0.summary.sd
    assert reldif(real("`r(v)'"), `sd') < 1e-12
    t_get variables.0.summary.min
    t_eq "`r(v)'" "`min'"
    t_get variables.0.summary.max
    t_eq "`r(v)'" "`max'"
    t_get variables.1.name
    t_eq "`r(v)'" "mpg"
    t_get variables.1.role
    t_eq "`r(v)'" "predictor"
    t_get variables.1.summary.median
    t_eq "`r(v)'" "20"
    * foreign: value labels as levels, the base level as reference.
    t_get variables.2.name
    t_eq "`r(v)'" "foreign"
    t_get variables.2.type
    t_eq "`r(v)'" "categorical"
    t_get variables.2.levels.0
    t_eq "`r(v)'" "Domestic"
    t_get variables.2.levels.1
    t_eq "`r(v)'" "Foreign"
    t_get variables.2.reference
    t_eq "`r(v)'" "Domestic"
    t_get variables.2.summary.mean
    t_eq "`r(v)'" ""
    quietly count if e(sample) & foreign == 0
    local ndom = r(N)
    t_get variables.2.summary.top.0.value
    t_eq "`r(v)'" "Domestic"
    t_get variables.2.summary.top.0.count
    t_eq "`r(v)'" "`ndom'"
    * rep78 has no value label: levels are the numbers.
    t_get variables.3.name
    t_eq "`r(v)'" "rep78"
    t_get variables.3.levels.#
    t_eq "`r(v)'" "5"
    t_get variables.3.reference
    t_eq "`r(v)'" "1"
    * Terms match the coefficient table; _cons has none.
    t_get terms.#
    t_eq "`r(v)'" "7"
    t_get terms.0.term
    t_eq "`r(v)'" "mpg"
    t_get terms.0.parts.0.variable
    t_eq "`r(v)'" "mpg"
    t_get terms.0.parts.0.level
    t_eq "`r(v)'" ""
    t_get terms.1.term
    t_eq "`r(v)'" "1.foreign"
    t_get terms.1.parts.0.level
    t_eq "`r(v)'" "Foreign"
    t_get tables.0.rows.2.0
    t_eq "`r(v)'" "1.foreign#c.mpg"
    t_get terms.2.term
    t_eq "`r(v)'" "1.foreign#c.mpg"
    t_get terms.2.parts.#
    t_eq "`r(v)'" "2"
    t_get terms.2.parts.0.variable
    t_eq "`r(v)'" "foreign"
    t_get terms.2.parts.0.level
    t_eq "`r(v)'" "Foreign"
    t_get terms.2.parts.1.variable
    t_eq "`r(v)'" "mpg"
    t_get terms.3.parts.0.level
    t_eq "`r(v)'" "2"
    * The temporary sample marker is gone and the data unchanged.
    assert c(changed) == 0
    assert c(k) == 12
}
t_end `=_rc'

t_begin estimates: variables for mixed groups, weights, offsets, and lags
capture noisily {
    webuse pig, clear
    mixed weight week || id:
    t_model
    t_get variables.2.name
    t_eq "`r(v)'" "id"
    t_get variables.2.role
    t_eq "`r(v)'" "group"
    t_get variables.2.summary.distinct
    t_eq "`r(v)'" "48"
    t_get variables.2.levels.#
    t_eq "`r(v)'" ""

    sysuse auto, clear
    regress price mpg [aweight = weight]
    t_model
    t_get variables.2.name
    t_eq "`r(v)'" "weight"
    t_get variables.2.role
    t_eq "`r(v)'" "weight"

    generate double miles = 1000 + _n
    poisson rep78 mpg, exposure(miles)
    t_model
    t_get variables.2.name
    t_eq "`r(v)'" "miles"
    t_get variables.2.role
    t_eq "`r(v)'" "offset"

    * A labeled response is categorical, without a reference.
    logit foreign mpg ib3.rep78
    t_model
    t_get variables.0.type
    t_eq "`r(v)'" "categorical"
    t_get variables.0.reference
    t_eq "`r(v)'" ""
    t_get variables.2.reference
    t_eq "`r(v)'" "3"
    t_get variables.2.levels.0
    t_eq "`r(v)'" "3"

    * Multi-equation terms carry the equation prefix.
    mlogit rep78 mpg
    t_model
    t_get variables.0.type
    t_eq "`r(v)'" "categorical"
    mata: st_local("v", fw_get(J, "tables.0.rows.2.0"))
    t_get terms.1.term
    t_eq "`r(v)'" "`v'"
    t_get terms.1.parts.0.variable
    t_eq "`r(v)'" "mpg"

    * Time-series operators map to the variable they act on.
    clear
    set obs 30
    generate t = _n
    tsset t
    generate double y = sin(t) + t / 10
    generate double x = cos(t)
    regress y L.x
    t_model
    t_get terms.0.term
    t_eq "`r(v)'" "L.x"
    t_get terms.0.parts.0.variable
    t_eq "`r(v)'" "x"
}
t_end `=_rc'

t_begin estimates: no estimation data leaves out variables and terms
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store fwvars
    clear
    estimates restore fwvars
    t_model
    t_get variables.#
    t_eq "`r(v)'" ""
    t_get terms.#
    t_eq "`r(v)'" ""
    estimates drop fwvars
}
t_end `=_rc'

* ---------------------------------------------------------------------------
* Bayesian models. bayesmh runs on Stata 14; the bayes prefix needs Stata 15,
* and R-hat from several chains needs Stata 16.
* ---------------------------------------------------------------------------

* A table column's value by name in row r. Returns r(v).
mata:
string scalar t_cell_value(transmorphic J, real scalar t, real scalar r, string scalar name)
{
    p = "tables." + strofreal(t)
    n = strtoreal(fw_get(J, p + ".columns.#"))
    for (i = 0; i < n; i++) {
        if (fw_get(J, p + ".columns." + strofreal(i) + ".name") == name) {
            return(fw_get(J, p + ".rows." + strofreal(r) + "." + strofreal(i)))
        }
    }
    return("(no column)")
}
end

capture program drop t_cell
program define t_cell, rclass
    args t r name
    mata: st_local("v", t_cell_value(J, `t', `r', "`name'"))
    return local v `"`v'"'
end

t_begin estimates: bayesmh logit publishes posterior summaries and odds ratios
capture noisily {
    sysuse auto, clear
    set seed 20261118
    bayesmh foreign mpg weight, likelihood(logit) prior({foreign:}, normal(0, 100)) ///
        mcmcsize(1000) burnin(500)
    matrix Mn = e(mean)
    matrix Sd = e(sd)
    matrix Cr = e(cri)
    matrix Es = e(ess)
    t_model
    t_get model.inference
    t_eq "`r(v)'" "bayesian"
    t_get model.type
    t_eq "`r(v)'" "glm"
    t_get model.family
    t_eq "`r(v)'" "binomial"
    t_get model.link
    t_eq "`r(v)'" "logit"
    t_get model.response
    t_eq "`r(v)'" "foreign"
    t_get model.exponentiate
    t_eq "`r(v)'" "Odds ratio"
    t_get source.class.0
    t_eq "`r(v)'" "bayesmh"
    t_get tables.0.role
    t_eq "`r(v)'" "coefficients"
    t_get tables.0.row_count
    t_eq "`r(v)'" "3"
    t_cell 0 0 term
    t_eq "`r(v)'" "mpg"
    t_cell 0 2 term
    t_eq "`r(v)'" "(Intercept)"
    t_cell 0 0 estimate
    assert reldif(real("`r(v)'"), Mn[1, 1]) < 1e-12
    t_cell 0 0 std_error
    assert reldif(real("`r(v)'"), Sd[1, 1]) < 1e-12
    t_cell 0 0 conf_low
    assert reldif(real("`r(v)'"), Cr[1, 1]) < 1e-12
    t_cell 0 0 conf_high
    assert reldif(real("`r(v)'"), Cr[2, 1]) < 1e-12
    t_cell 0 1 ess_bulk
    assert reldif(real("`r(v)'"), Es[1, 2]) < 1e-12
    * No tests, no tail ESS, and no R-hat from one chain.
    foreach c in p_value statistic ess_tail rhat {
        t_cell 0 0 `c'
        t_eq "`r(v)'" "(no column)"
    }
    * Ratios summarize the exponentiated draws.
    t_cell 0 0 ratio_estimate
    local or = real("`r(v)'")
    t_cell 0 0 ratio_conf_low
    local orlo = real("`r(v)'")
    t_cell 0 0 ratio_std_error
    local orsd = real("`r(v)'")
    quietly bayesstats summary (exp({foreign:mpg}))
    matrix S = r(summary)
    assert reldif(`or', S[1, 1]) < 1e-12
    assert reldif(`orsd', S[1, 2]) < 1e-12
    assert reldif(`orlo', S[1, 5]) < 1e-12
    assert abs(`or' - exp(Mn[1, 1])) > 1e-9
    t_cell 0 2 ratio_estimate
    t_eq "`r(v)'" ""
    * Priors, as typed.
    t_get tables.1.role
    t_eq "`r(v)'" "priors"
    t_get tables.1.rows.0.0
    t_eq "`r(v)'" "{foreign:mpg weight _cons}"
    t_get tables.1.rows.0.1
    t_eq "`r(v)'" "normal(0, 100)"
    t_get tables.1.rows.0.2
    t_eq "`r(v)'" "user"
    t_metric confidence_level
    assert reldif(real("`r(v)'"), 0.95) < 1e-12
    t_metric interval_method
    t_eq "`r(v)'" "Equal-tailed"
    t_metric chains
    t_eq "`r(v)'" "1"
    t_metric draws
    t_eq "`r(v)'" "1000"
    t_metric warmup
    t_eq "`r(v)'" "500"
    t_metric sampler
    assert strpos("`r(v)'", "Metropolis") & !strpos("`r(v)'", "sampling")
    t_metric acceptance_rate
    assert reldif(real("`r(v)'"), e(arate)) < 1e-12
    t_metric efficiency_min
    assert reldif(real("`r(v)'"), e(eff_min)) < 1e-12
    t_metric command
    assert strpos(`"`r(v)'"', "bayesmh foreign mpg weight") == 1
    t_metric aic
    t_eq "`r(v)'" ""
    * Variables and terms, as for frequentist models.
    t_get variables.0.name
    t_eq "`r(v)'" "foreign"
    t_get variables.0.role
    t_eq "`r(v)'" "response"
    t_get terms.1.term
    t_eq "`r(v)'" "weight"
    t_get terms.#
    t_eq "`r(v)'" "2"
}
t_end `=_rc'

t_begin estimates: bayesmh normal regression with HPD intervals and a variance
capture noisily {
    sysuse auto, clear
    set seed 20261118
    bayesmh price mpg i.foreign, likelihood(normal({var})) prior({price:}, normal(0, 1e8)) ///
        prior({var}, igamma(.01, .01)) block({var}) mcmcsize(500) burnin(200) hpd clevel(90)
    matrix Cr = e(cri)
    t_model
    t_get model.type
    t_eq "`r(v)'" "linear"
    t_get model.exponentiate
    t_eq "`r(v)'" ""
    t_cell 0 0 ratio_estimate
    t_eq "`r(v)'" "(no column)"
    t_cell 0 1 term
    t_eq "`r(v)'" "1.foreign"
    t_cell 0 0 conf_low
    assert reldif(real("`r(v)'"), Cr[1, 1]) < 1e-12
    t_metric interval_method
    t_eq "`r(v)'" "HDI"
    t_metric confidence_level
    assert reldif(real("`r(v)'"), 0.9) < 1e-12
    * Scalar parameters go in their own table.
    t_get tables.1.role
    t_eq "`r(v)'" "parameters"
    t_get tables.1.rows.0.0
    t_eq "`r(v)'" "var"
    t_get tables.2.row_count
    t_eq "`r(v)'" "2"
    t_get tables.2.rows.0.0
    t_eq "`r(v)'" "{price:mpg 1.foreign _cons}"
    t_get tables.2.rows.1.0
    t_eq "`r(v)'" "{var}"
    t_get tables.2.rows.1.1
    t_eq "`r(v)'" "igamma(.01, .01)"
    t_get terms.1.parts.0.level
    t_eq "`r(v)'" "Foreign"
    t_get variables.2.reference
    t_eq "`r(v)'" "Domestic"
    * level() other than the default recomputes the interval.
    mata: J = fw_json_parse(fw_model_json(80))
    quietly bayesstats summary {price:mpg}, clevel(80) hpd
    matrix S = r(summary)
    t_cell 0 0 conf_low
    assert reldif(real("`r(v)'"), S[1, 5]) < 1e-12
    t_metric confidence_level
    assert reldif(real("`r(v)'"), 0.8) < 1e-12
}
t_end `=_rc'

t_begin estimates: bayesmh ologit keeps cutpoints off the ratio scale
capture noisily {
    sysuse auto, clear
    set seed 20261118
    bayesmh rep78 mpg, likelihood(ologit) prior({rep78:}, normal(0, 100)) mcmcsize(500) burnin(200)
    t_model
    t_get model.type
    t_eq "`r(v)'" "ordinal"
    t_cell 0 0 term
    t_eq "`r(v)'" "mpg"
    t_cell 0 0 ratio_estimate
    assert real("`r(v)'") > 0
    t_cell 0 1 ratio_estimate
    t_eq "`r(v)'" ""
    t_get terms.#
    t_eq "`r(v)'" "1"
}
t_end `=_rc'

t_begin estimates: prior() options parse from the command line
capture noisily {
    mata: P = fw__prior_options("y x, likelihood(logit) prior({y:x z}, normal(0, 100)) noprior(1) prior({var} {s}, igamma(0.01, 0.01)) prior({y:_cons}, flat)")
    mata: assert(rows(P) == 3)
    mata: assert(P[1, 1] == "{y:x z}" & P[1, 2] == "normal(0, 100)")
    mata: assert(P[2, 2] == "igamma(0.01, 0.01)" & P[3, 2] == "flat")
    mata: assert(fw__prior_covers("{y:x z}", "y:z") & !fw__prior_covers("{y:x z}", "y:_cons"))
    mata: assert(fw__prior_covers("{y:}", "y:_cons") & fw__prior_covers("{var} {s}", "s") & !fw__prior_covers("{y:}", "var"))
    mata: assert(fw__prior_params(("y:x", "y:0b.f", "y:1.f", "y:_cons", "var")) == "{y:x 1.f _cons} {var}")
}
t_end `=_rc'

if c(stata_version) >= 15 {
    t_begin estimates: the bayes prefix names the model from the command it ran
    capture noisily {
        sysuse auto, clear
        set seed 20261118
        bayes, mcmcsize(500) burnin(200): logit foreign mpg
        t_model
        t_get source.class.0
        t_eq "`r(v)'" "bayes"
        t_get source.class.1
        t_eq "`r(v)'" "logit"
        t_get model.inference
        t_eq "`r(v)'" "bayesian"
        t_get model.link
        t_eq "`r(v)'" "logit"
        t_cell 0 0 term
        t_eq "`r(v)'" "mpg"
        t_cell 0 0 ratio_estimate
        assert real("`r(v)'") > 0
        t_get tables.1.role
        t_eq "`r(v)'" "priors"
        t_get tables.1.rows.0.2
        t_eq "`r(v)'" "default"
    }
    t_end `=_rc'
}
else t_skip "estimates: the bayes prefix needs Stata 15"

if c(stata_version) >= 16 {
    t_begin estimates: several chains give R-hat
    capture noisily {
        sysuse auto, clear
        set seed 20261118
        bayes, nchains(2) mcmcsize(500) burnin(200): regress price mpg
        t_model
        t_metric chains
        t_eq "`r(v)'" "2"
        t_metric draws
        t_eq "`r(v)'" "1000"
        quietly bayesstats grubin
        matrix R = r(Rc)
        t_cell 0 0 rhat
        assert reldif(real("`r(v)'"), R[1, 1]) < 1e-9
        t_metric rhat_max
        assert real("`r(v)'") >= 1
    }
    t_end `=_rc'
}
else t_skip "estimates: R-hat from several chains needs Stata 16"
