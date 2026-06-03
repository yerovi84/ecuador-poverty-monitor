epm_valid_survey_types <- function() {
  c("mensual", "trimestral", "anual")
}

epm_get_layers <- function(periods_config) {
  layers <- periods_config$layers

  if (!is.list(layers) || length(layers) == 0L) {
    .epm_abort("`periods_config$layers` must be a non-empty named list.")
  }

  names(layers)
}

epm_get_layer_config <- function(layer, periods_config) {
  layer_config <- periods_config$layers[[layer]]

  if (is.null(layer_config)) {
    .epm_abort(sprintf("Unknown period layer: %s", layer))
  }

  layer_config
}

epm_resolve_period <- function(layer, periods_config, available_periods = NULL) {
  layer_config <- epm_get_layer_config(layer, periods_config)
  period <- layer_config$period

  if (!.epm_is_scalar_character(period)) {
    .epm_abort(sprintf("Layer `%s` must define a string `period`.", layer))
  }

  if (!epm_is_latest_period(period)) {
    return(period)
  }

  if (is.null(available_periods)) {
    return("latest")
  }

  available_periods <- sort(unique(as.character(available_periods)))

  if (length(available_periods) == 0L) {
    .epm_abort(sprintf("No available periods were provided for layer `%s`.", layer))
  }

  tail(available_periods, 1)
}

epm_layer_survey_type <- function(layer, periods_config) {
  survey_type <- epm_get_layer_config(layer, periods_config)$survey_type

  if (!survey_type %in% epm_valid_survey_types()) {
    .epm_abort(sprintf("Layer `%s` has invalid survey type `%s`.", layer, survey_type))
  }

  survey_type
}

epm_layer_allowed_domains <- function(layer, periods_config) {
  allowed <- epm_get_layer_config(layer, periods_config)$allowed_domains

  if (!is.character(allowed) || length(allowed) == 0L) {
    .epm_abort(sprintf("Layer `%s` must define non-empty `allowed_domains`.", layer))
  }

  allowed
}

epm_is_latest_period <- function(period) {
  .epm_is_scalar_character(period) && identical(tolower(period), "latest")
}
