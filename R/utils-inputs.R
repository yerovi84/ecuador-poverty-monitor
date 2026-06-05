epm_expected_input_filename <- function(layer, input_name, paths_config = NULL) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  input_contract <- paths_config$raw_data_layout[[layer]]$expected_files[[input_name]]

  if (is.null(input_contract)) {
    .epm_abort(sprintf("Unknown expected input `%s` for raw layer `%s`.", input_name, layer))
  }

  filename <- input_contract$filename
  pattern <- input_contract$pattern

  if (.epm_is_scalar_character(filename)) {
    return(filename)
  }

  if (.epm_is_scalar_character(pattern) && !epm_has_glob_metachar(pattern)) {
    return(pattern)
  }

  .epm_abort(sprintf(
    "Expected input `%s` for raw layer `%s` must define an exact `filename`; ambiguous pattern `%s` is not allowed.",
    input_name,
    layer,
    ifelse(is.null(pattern), "<missing>", pattern)
  ))
}

epm_has_glob_metachar <- function(pattern) {
  if (!.epm_is_scalar_character(pattern)) {
    return(FALSE)
  }

  chars <- strsplit(pattern, "", fixed = TRUE)[[1]]
  any(chars %in% c("*", "?", "[", "]", "{", "}"))
}

epm_resolve_expected_input_file <- function(layer,
                                            input_name,
                                            paths_config = NULL,
                                            required = TRUE) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  raw_dir <- epm_layer_raw_dir(layer, paths_config = paths_config, required = required)

  if (is.na(raw_dir)) {
    return(list(
      input_name = input_name,
      basename = NA_character_,
      path = NA_character_,
      exists = FALSE
    ))
  }

  filename <- epm_expected_input_filename(layer, input_name, paths_config)
  path <- file.path(raw_dir, filename)
  exists <- file.exists(path)

  if (isTRUE(required) && !exists) {
    .epm_abort(sprintf(
      "Required `%s` input for raw layer `%s` was not found: %s",
      input_name,
      layer,
      filename
    ))
  }

  list(
    input_name = input_name,
    basename = basename(path),
    path = normalizePath(path, winslash = "/", mustWork = FALSE),
    exists = exists
  )
}

epm_resolve_annual_input_files <- function(paths_config = NULL, required = TRUE) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  inputs <- c("persona", "vivienda")
  resolved <- lapply(inputs, function(input_name) {
    epm_resolve_expected_input_file(
      layer = "annual",
      input_name = input_name,
      paths_config = paths_config,
      required = required
    )
  })

  names(resolved) <- inputs
  resolved
}

epm_resolve_annual_benchmark_file <- function(paths_config = NULL, required = FALSE) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  epm_resolve_expected_input_file(
    layer = "annual",
    input_name = "official_tables",
    paths_config = paths_config,
    required = required
  )
}

epm_expected_input_member <- function(layer, input_name, paths_config = NULL) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  input_contract <- paths_config$raw_data_layout[[layer]]$expected_files[[input_name]]

  if (is.null(input_contract)) {
    .epm_abort(sprintf("Unknown expected input `%s` for raw layer `%s`.", input_name, layer))
  }

  member <- input_contract$member

  if (.epm_is_scalar_character(member)) {
    return(member)
  }

  NA_character_
}

epm_input_basenames <- function(resolved_inputs) {
  vapply(resolved_inputs, function(input) input$basename, character(1))
}
