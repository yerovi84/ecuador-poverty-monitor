epm_required_output_columns <- function(indicators_config) {
  required <- indicators_config$common_output_columns$required

  if (!is.character(required) || length(required) == 0L) {
    .epm_abort("`common_output_columns.required` must be a non-empty character vector.")
  }

  required
}

epm_recommended_output_columns <- function(indicators_config) {
  recommended <- indicators_config$common_output_columns$recommended

  if (is.null(recommended)) {
    return(character())
  }

  if (!is.character(recommended)) {
    .epm_abort("`common_output_columns.recommended` must be a character vector.")
  }

  recommended
}

epm_validate_output_schema <- function(data, indicators_config, strict = TRUE) {
  if (!is.data.frame(data)) {
    .epm_abort("`data` must be a data frame.")
  }

  missing_required <- setdiff(epm_required_output_columns(indicators_config), names(data))

  if (length(missing_required) > 0L) {
    .epm_abort(sprintf(
      "Output is missing required column(s): %s",
      paste(missing_required, collapse = ", ")
    ))
  }

  if (isTRUE(strict)) {
    missing_recommended <- setdiff(epm_recommended_output_columns(indicators_config), names(data))

    if (length(missing_recommended) > 0L) {
      warning(sprintf(
        "Output is missing recommended column(s): %s",
        paste(missing_recommended, collapse = ", ")
      ), call. = FALSE)
    }
  }

  invisible(TRUE)
}

epm_add_build_metadata <- function(data, period, survey_type, source_layer) {
  if (!is.data.frame(data)) {
    .epm_abort("`data` must be a data frame.")
  }

  data$period <- period
  data$survey_type <- survey_type
  data$source_layer <- source_layer
  data$build_timestamp <- as.character(Sys.time())
  data
}

epm_save_output <- function(data, path) {
  if (!is.data.frame(data)) {
    .epm_abort("`data` must be a data frame.")
  }

  if (!.epm_is_scalar_character(path)) {
    .epm_abort("`path` must be a non-empty character string.")
  }

  if (!identical(tolower(tools::file_ext(path)), "rds")) {
    .epm_abort("Pipeline outputs must be saved as `.rds` files.")
  }

  epm_make_dir(dirname(path))
  saveRDS(data, path)
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}

epm_read_output <- function(path, required = TRUE) {
  if (!file.exists(path)) {
    if (isTRUE(required)) {
      .epm_abort(sprintf("Required output file not found: %s", path))
    }
    return(NULL)
  }

  readRDS(path)
}

epm_empty_output <- function(indicator_id = NA_character_) {
  data.frame(
    indicator_id = character(),
    indicator_label = character(),
    indicator_family = character(),
    period = character(),
    survey_type = character(),
    domain = character(),
    domain_value = character(),
    estimate = numeric(),
    estimate_type = character(),
    unit = character(),
    source_layer = character(),
    build_timestamp = character(),
    stringsAsFactors = FALSE
  )
}
