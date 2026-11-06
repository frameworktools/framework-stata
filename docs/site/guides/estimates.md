---
id: estimates
title: Estimation results
description: Models from regress, logit, mixed, stcox, and other commands
section: features
position: 4
---

## Models

`fw_publish, estimates` publishes the current estimation results as a model. It writes the same `model.json` that R and Python publish, so Framework Cloud and the offline reader show a Stata model like any other.

```stata
sysuse auto, clear
regress price mpg weight i.foreign
fw_publish, estimates title("Price model") slug(price-model)
```

The model has a coefficient table with estimates, standard errors, test statistics, p-values, and confidence intervals, plus fit statistics. The mapping runs in Mata. Python is not needed.

## Supported commands

| Command | Model type | Ratio view | Extras |
|---------|------------|------------|--------|
| `regress` | linear | | R², adjusted R², residual SD |
| `logit`, `logistic` | glm, binomial, logit | odds ratio | pseudo R², null log likelihood |
| `probit` | glm, binomial, probit | | pseudo R² |
| `poisson` | glm, poisson, log | rate ratio | pseudo R² |
| `nbreg` | glm, negative binomial, log | rate ratio | alpha |
| `glm` | glm, family and link from Stata | by link | deviance, dispersion |
| `mixed` | mixed | | random effects, groups, REML |
| `stcox` | survival | hazard ratio | events |
| `ivregress` | linear | | estimator, instruments |

Every model also gets the number of observations and, when Stata has a log likelihood, AIC and BIC.

Other commands that leave `e(b)` and `e(V)` publish a generic coefficient table. `fw_publish` prints a note when it does.

## Coefficient table

- Estimates stay on the model scale. `logistic` results are stored as log odds. The reader offers odds, rate, and hazard ratios.
- `_cons` becomes `(Intercept)`.
- Base and omitted factor levels are left out.
- Multi-equation models prefix terms with the equation name.
- Models with residual degrees of freedom use t statistics. The rest use z statistics.

## Ancillary parameters

Parameters that are not coefficients stay out of the coefficient table:

- `nbreg` reports `alpha`, or `delta` with `dispersion(constant)`, as a fit statistic. R and Python report theta the same way.
- Other free parameters, such as tobit's `var(e.y)` and ologit's cutpoints, go in an **Ancillary parameters** table. Variances, covariances, correlations, cutpoints, and tobit's sigma get no test, as in Stata's output. Variances and standard deviations get Stata's log-scale interval, and correlations its hyperbolic-arctangent interval.
- `tobit` also reports `sigma`, the residual standard deviation.

`level()` sets the confidence level. The default is `c(level)`, 95 unless you changed it with `set level`, as in R and Python. `fw_publish` does not read the level of the estimation command: after `regress, level(90)`, give `level(90)` to publish 90% intervals.

```stata
logit foreign price mpg
fw_publish, estimates level(90)
```

## Mixed models

`mixed` adds a random-effects table: a standard deviation for each component, correlations, and the residual. It covers independent, identity, exchangeable, and unstructured covariance. The model also records the number of groups at each level and whether it used REML.

```stata
webuse pig, clear
mixed weight week || id: week, covariance(unstructured)
fw_publish, estimates title("Growth model")
```

## Saved copy

`saving()` keeps a copy of `model.json`.

```stata
fw_publish, estimates saving("$fw_outputs/price-model.json", replace)
```

Destinations, versions, and stored results work as for files. See [Publishing](guide:publishing).
