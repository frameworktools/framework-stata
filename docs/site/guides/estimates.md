---
id: estimates
title: Estimation results
description: Structured model artifacts from regress, logit, mixed, stcox, and other estimators
section: features
position: 4
---

## Model serialization

`fw_publish, estimates` serializes Stata's active estimation results into the shared `model.json` representation used by R and Python. Framework Cloud and the offline reader display coefficients, forest plots, and fit statistics identically across languages.

```stata
sysuse auto, clear
regress price mpg weight i.foreign
fw_publish, estimates title("Price model") slug(price-model)
```

Model extraction runs natively in Mata without Python. Each artifact includes point estimates, standard errors, test statistics, p-values, confidence intervals, and model-level fit statistics.

## Supported estimators

| Command | Model type | Ratio scale | Additional fit statistics |
|---|---|---|---|
| `regress` | linear | | R², adjusted R², residual SD |
| `logit`, `logistic` | glm, binomial, logit | odds ratio | pseudo R², null log likelihood |
| `probit` | glm, binomial, probit | | pseudo R² |
| `poisson` | glm, poisson, log | rate ratio | pseudo R² |
| `nbreg` | glm, negative binomial, log | rate ratio | alpha |
| `glm` | glm, family and link from Stata | by link | deviance, dispersion |
| `mixed` | mixed | | random effects, group counts, REML |
| `stcox` | survival | hazard ratio | event count |
| `ivregress` | linear | | estimator, instrument list |

Every model records the observation count (`e(N)`) alongside AIC and BIC whenever Stata reports a log likelihood.

Other estimation commands that populate `e(b)` and `e(V)` publish a generic coefficient table, and `fw_publish` prints a notice when using the generic fallback.

## Coefficient table rules

- Estimates are stored on the linear predictor scale (for example, `logistic` stores log odds while the reader provides an odds-ratio toggle).
- `_cons` is normalized to `(Intercept)`.
- Base and omitted factor levels are excluded.
- Multi-equation estimators prefix term names with their equation name.
- Estimators with residual degrees of freedom compute *t* statistics; others compute *z* statistics.

## Ancillary parameters and confidence levels

Non-regression parameters are separated from main coefficients:

- `nbreg` records `alpha` (or `delta` under `dispersion(constant)`) as a fit statistic, matching `theta` in R and Python.
- Auxiliary free parameters, such as `tobit` variance `var(e.y)` and `ologit` cutpoints, appear in an **Ancillary parameters** table without hypothesis tests where Stata omits them. Variance and standard deviation intervals use Stata's log transformation, and correlation intervals use the inverse hyperbolic tangent transformation.
- `tobit` also records residual `sigma` in fit statistics.

Pass `level()` to set the confidence level. It defaults to `c(level)` (95 unless changed via `set level`). Because Stata does not store the display level passed to the estimation command, pass `level(90)` explicitly on `fw_publish` after `regress ..., level(90)`:

```stata
logit foreign price mpg
fw_publish, estimates level(90)
```

## Mixed-effects models

`mixed` adds a random-effects summary containing component standard deviations, correlations, residual standard deviation, per-level group counts, and whether estimation used REML or ML. Supported covariance structures are `independent`, `identity`, `exchangeable`, and `unstructured`.

```stata
webuse pig, clear
mixed weight week || id: week, covariance(unstructured)
fw_publish, estimates title("Growth model")
```

## Local JSON copy

Pass `saving()` to write a local copy of `model.json` alongside publishing:

```stata
fw_publish, estimates saving("$fw_outputs/price-model.json", replace)
```

Destinations, version numbering, private-path checks on the underlying dataset, and `r()` return values follow the same rules as file publishing. See [Publishing](guide:publishing).
