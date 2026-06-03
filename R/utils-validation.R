epm_validate_paths_config <- function(paths_config) {
  epm_check_required_config(
    paths_config,
    c("path_policy", "environment", "roots", "raw_data_layout", "derived_data_layout", "validation")
  )

  if (!identical(paths_config$environment$raw_data_root_env, "EPM_RAW_DATA_ROOT")) {
    .epm_abort("Raw data root must be controlled by `EPM_RAW_DATA_ROOT`.")
  }

  scan_config <- paths_config
  scan_config$validation$forbidden_patterns <- NULL
  forbidden <- epm_detect_forbidden_paths(scan_config, paths_config$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort(sprintf(
      "Forbidden private path pattern detected in paths config: %s",
      paste(forbidden, collapse = ", ")
    ))
  }

  invisible(TRUE)
}

epm_validate_periods_config <- function(periods_config) {
  epm_check_required_config(periods_config, c("layers", "period_strategy", "editorial_rules"))

  for (layer in epm_get_layers(periods_config)) {
    survey_type <- epm_layer_survey_type(layer, periods_config)
    allowed_domains <- epm_layer_allowed_domains(layer, periods_config)

    if (survey_type %in% c("mensual", "trimestral") && "province" %in% allowed_domains) {
      .epm_abort("`province` is only allowed for annual survey layers.")
    }

    if (identical(survey_type, "mensual") && "five_cities" %in% allowed_domains) {
      .epm_abort("`five_cities` is not allowed for monthly survey layers.")
    }
  }

  invisible(TRUE)
}

epm_validate_domains_config <- function(domains_config) {
  epm_check_required_config(domains_config, c("domains", "rules"))
  registry <- epm_domain_registry(domains_config)

  for (domain in names(registry)) {
    valid_for <- registry[[domain]]$valid_for

    if (is.null(valid_for)) {
      valid_for <- character()
    }

    invalid <- setdiff(valid_for, epm_valid_survey_types())

    if (length(invalid) > 0L) {
      .epm_abort(sprintf(
        "Domain `%s` has invalid survey type(s): %s",
        domain,
        paste(invalid, collapse = ", ")
      ))
    }
  }

  for (domain in c("national", "area")) {
    valid_for <- registry[[domain]]$valid_for
    if (!setequal(valid_for, epm_valid_survey_types())) {
      .epm_abort(sprintf("Domain `%s` must be valid for monthly, quarterly, and annual surveys.", domain))
    }
  }

  if (!setequal(registry$province$valid_for, "anual")) {
    .epm_abort("Domain `province` must only be valid for annual surveys.")
  }

  if (!setequal(registry$five_cities$valid_for, c("trimestral", "anual"))) {
    .epm_abort("Domain `five_cities` must only be valid for quarterly and annual surveys.")
  }

  invisible(TRUE)
}

epm_validate_indicators_config <- function(indicators_config, domains_config) {
  epm_check_required_config(
    indicators_config,
    c("indicator_contract", "families", "common_output_columns", "indicators")
  )

  epm_required_output_columns(indicators_config)
  epm_recommended_output_columns(indicators_config)
  epm_validate_indicator_domains(indicators_config, domains_config)

  indicators <- indicators_config$indicators

  for (indicator_id in names(indicators)) {
    indicator <- indicators[[indicator_id]]

    if (!isTRUE(indicator$enabled)) {
      next
    }

    required_fields <- c("family", "source_layer", "survey_type", "output_group", "output_name")
    missing <- required_fields[vapply(indicator[required_fields], is.null, logical(1))]

    if (length(missing) > 0L) {
      .epm_abort(sprintf(
        "Enabled indicator `%s` is missing field(s): %s",
        indicator_id,
        paste(missing, collapse = ", ")
      ))
    }
  }

  invisible(TRUE)
}

epm_validate_all_configs <- function(config) {
  epm_check_required_config(config, c("paths", "periods", "domains", "indicators"))
  epm_validate_paths_config(config$paths)
  epm_validate_periods_config(config$periods)
  epm_validate_domains_config(config$domains)
  epm_validate_indicators_config(config$indicators, config$domains)
  invisible(TRUE)
}

epm_assert_no_raw_microdata_tracked <- function() {
  tracked <- tryCatch(
    system2("git", c("ls-files"), stdout = TRUE, stderr = TRUE),
    error = function(error) character()
  )

  if (length(tracked) == 0L) {
    return(invisible(TRUE))
  }

  forbidden <- c(".sav", ".dta", ".por", ".sas7bdat")
  hits <- tracked[tolower(tools::file_ext(tracked)) %in% sub("^\\.", "", forbidden)]

  if (length(hits) > 0L) {
    .epm_abort(sprintf(
      "Raw microdata file(s) are tracked by git: %s",
      paste(hits, collapse = ", ")
    ))
  }

  invisible(TRUE)
}

epm_smoke_test_config <- function() {
  config <- epm_load_config()
  epm_validate_all_configs(config)
  epm_assert_no_raw_microdata_tracked()
  invisible(config)
}
