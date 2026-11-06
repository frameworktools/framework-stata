* Example 4: publish estimation results as models.
* Run 01-project.do and 02-data.do first.

cd "$FW_EXAMPLE_PROJECT"
fw_project, quietly
fw_use inputs.final.analysis, clear

* A linear model.
regress price_k mpg weight i.foreign
fw_publish, estimates title("Price model") slug(price-model)

* A logit model. Readers can switch to odds ratios.
logit foreign mpg weight
fw_publish, estimates title("Origin model") slug(origin-model) ///
    saving("$fw_outputs_tables/origin-model.json", replace)

* To publish to Framework Cloud instead, connect once and add a project
* token to the project's .env file:
*   fw_login
*   fw_publish, estimates to(cloud)

* Run 05-cleanup.do to remove the example project when you are done.
