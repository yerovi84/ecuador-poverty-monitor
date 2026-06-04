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

epm_assert_province_contract <- function(config) {
  province <- epm_domain_registry(config$domains)$province

  if (is.null(province)) {
    .epm_abort("Annual layer includes `province`, but the domain is missing from config/domains.yml.")
  }

  if (!.epm_is_scalar_character(province$variable)) {
    .epm_abort("Domain `province` must define a non-empty variable name.")
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

layer <- "annual"
survey_type <- "anual"
layer_config <- epm_require_layer(layer, survey_type, config)
period <- epm_resolve_period(layer, config$periods)
allowed_domains <- epm_layer_allowed_domains(layer, config$periods)

epm_validate_layer_domains(layer, survey_type, allowed_domains, config)

if ("province" %in% allowed_domains) {
  epm_assert_province_contract(config)
}

output_paths <- epm_prepare_layer_outputs(layer, config)

message("Annual core builder scaffold complete.")
message(sprintf("Resolved annual period: %s", period))
message(sprintf("Validated annual domains: %s", paste(allowed_domains, collapse = ", ")))
message("Prepared annual output routes:")
for (output_name in names(output_paths)) {
  message(sprintf("- %s: %s", output_name, output_paths[[output_name]]))
}
message("Real annual indicator calculation is pending by design; no analytical output was written.")
