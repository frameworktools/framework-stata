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
    * Compare with estat sd.
    estat sd
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
    foreach v in 14 15 17 {
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
