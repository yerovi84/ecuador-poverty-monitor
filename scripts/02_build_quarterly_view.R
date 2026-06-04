source("scripts/00_setup.R")

epm_require_layer <- function(layer, expected_survey_type, config) {
  if (!layer %in% epm_get_layers(config$periods)) {
    .epm_abort(sprintf("Required period layer `%s` is missing from config/periods.yml.", layer))
  }

  layer_config <- epm_get_layer_config(layer, config$periods)

  if (!isTRUE(layer_config$enabled)) {
    .epm_abort(sprintf("Period layer `%s` must be enabled before building this output.", layer))
  }

  survey_type <- epm_layer_survey_type(layer, config$periods)

  if (!identical(survey_type, expected_survey_type)) {
    .epm_abort(sprintf(
      "Layer `%s` must use survey type `%s`; found `%s`.",
      layer,
      expected_survey_type,
      survey_type
    ))
  }

  layer_config
}

epm_validate_layer_domains <- function(layer, survey_type, allowed_domains, config) {
  for (domain in allowed_domains) {
    epm_validate_domain_period(domain, survey_type, config$domains)
  }
  invisible(TRUE)
}

epm_assert_five_cities_contract <- function(config) {
  five_cities <- epm_domain_registry(config$domains)$five_cities

  if (is.null(five_cities)) {
    .epm_abort("Quarterly layer includes `five_cities`, but the domain is missing from config/domains.yml.")
  }

  values <- five_cities$values

  if (!is.character(values) || length(values) != 5L || any(!nzchar(values))) {
    .epm_abort("Domain `five_cities` must define exactly five non-empty city names.")
  }

  invisible(TRUE)
}

epm_prepare_layer_outputs <- function(layer, config) {
  layer_dir <- epm_layer_derived_dir(layer, config$paths)
  epm_make_dir(layer_dir)

  output_names <- names(config$paths$derived_data_layout[[layer]]$outputs)

  if (!is.character(output_names) || length(output_names) == 0L) {
    .epm_abort(sprintf("Derived layer `%s` must define at least one output in config/paths.yml.", layer))
  }

  paths <- vapply(output_names, function(output_name) {
    epm_output_path(layer, output_name, config$paths)
  }, character(1))

  invisible(paths)
}

layer <- "quarterly"
survey_type <- "trimestral"
layer_config <- epm_require_layer(layer, survey_type, config)
period <- epm_resolve_period(layer, config$periods)
allowed_domains <- epm_layer_allowed_domains(layer, config$periods)

if ("province" %in% allowed_domains) {
  .epm_abort("Quarterly view cannot use `province`; province is only valid for annual outputs.")
}

epm_validate_layer_domains(layer, survey_type, allowed_domains, config)

if ("five_cities" %in% allowed_domains) {
  epm_assert_five_cities_contract(config)
}

output_paths <- epm_prepare_layer_outputs(layer, config)

message("Quarterly view builder scaffold complete.")
message(sprintf("Resolved quarterly period: %s", period))
message(sprintf("Validated quarterly domains: %s", paste(allowed_domains, collapse = ", ")))
message("Prepared quarterly output routes:")
for (output_name in names(output_paths)) {
  message(sprintf("- %s: %s", output_name, output_paths[[output_name]]))
}
message("Real quarterly indicator calculation is pending by design; no analytical output was written.")
