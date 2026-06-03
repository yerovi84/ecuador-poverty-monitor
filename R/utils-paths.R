epm_project_root <- function() {
  current <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  repeat {
    if (
      file.exists(file.path(current, "_quarto.yml")) &&
        dir.exists(file.path(current, "config"))
    ) {
      return(current)
    }

    parent <- dirname(current)

    if (identical(parent, current)) {
      .epm_abort("Could not find project root containing `_quarto.yml` and `config/`.")
    }

    current <- parent
  }
}

epm_raw_data_root <- function(required = FALSE) {
  value <- Sys.getenv("EPM_RAW_DATA_ROOT", unset = "")

  if (!nzchar(value)) {
    if (isTRUE(required)) {
      .epm_abort("`EPM_RAW_DATA_ROOT` is required to resolve raw microdata paths.")
    }
    return(NA_character_)
  }

  normalizePath(value, winslash = "/", mustWork = FALSE)
}

epm_derived_root <- function() {
  file.path(epm_project_root(), "data", "derived")
}

epm_make_dir <- function(path) {
  if (!.epm_is_scalar_character(path)) {
    .epm_abort("`path` must be a non-empty character string.")
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  normalizePath(path, winslash = "/", mustWork = TRUE)
}

epm_prepare_derived_dirs <- function(paths_config) {
  layout <- paths_config$derived_data_layout

  if (!is.list(layout) || length(layout) == 0L) {
    .epm_abort("`paths_config$derived_data_layout` must be a non-empty list.")
  }

  dirs <- vapply(layout, function(layer) {
    folder <- layer$folder

    if (!.epm_is_scalar_character(folder)) {
      .epm_abort("Each derived data layer must define a string `folder`.")
    }

    epm_make_dir(file.path(epm_project_root(), folder))
  }, character(1))

  invisible(unique(c(epm_make_dir(epm_derived_root()), dirs)))
}

epm_layer_raw_dir <- function(layer, paths_config = NULL, required = FALSE) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  if (!.epm_is_scalar_character(layer)) {
    .epm_abort("`layer` must be a non-empty character string.")
  }

  layer_config <- paths_config$raw_data_layout[[layer]]

  if (is.null(layer_config)) {
    .epm_abort(sprintf("Unknown raw data layer: %s", layer))
  }

  root <- epm_raw_data_root(required = required)

  if (is.na(root)) {
    return(NA_character_)
  }

  file.path(root, layer_config$folder)
}

epm_layer_derived_dir <- function(layer, paths_config = NULL) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  if (!.epm_is_scalar_character(layer)) {
    .epm_abort("`layer` must be a non-empty character string.")
  }

  layer_config <- paths_config$derived_data_layout[[layer]]

  if (is.null(layer_config)) {
    .epm_abort(sprintf("Unknown derived data layer: %s", layer))
  }

  file.path(epm_project_root(), layer_config$folder)
}

epm_output_path <- function(layer, output_name, paths_config = NULL) {
  if (is.null(paths_config)) {
    paths_config <- epm_load_config()$paths
  }

  layer_config <- paths_config$derived_data_layout[[layer]]

  if (is.null(layer_config)) {
    .epm_abort(sprintf("Unknown derived data layer: %s", layer))
  }

  output <- layer_config$outputs[[output_name]]

  if (!.epm_is_scalar_character(output)) {
    .epm_abort(sprintf("Unknown output `%s` for layer `%s`.", output_name, layer))
  }

  file.path(epm_derived_root(), output)
}

epm_detect_forbidden_paths <- function(x, forbidden_patterns = NULL) {
  if (is.null(forbidden_patterns)) {
    forbidden_patterns <- c(
      "C:/Users/",
      "C:\\Users\\",
      "/Users/",
      "/home/",
      "OneDrive",
      "Dropbox",
      "Google Drive"
    )
  }

  values <- unique(as.character(unlist(x, recursive = TRUE, use.names = FALSE)))
  values <- values[!is.na(values) & nzchar(values)]

  hits <- values[vapply(values, function(value) {
    any(vapply(forbidden_patterns, grepl, logical(1), x = value, fixed = TRUE))
  }, logical(1))]

  unique(hits)
}
