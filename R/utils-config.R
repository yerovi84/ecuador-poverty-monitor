.epm_abort <- function(message) {
  stop(message, call. = FALSE)
}

.epm_is_scalar_character <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

epm_read_yaml <- function(path) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    .epm_abort("Package `yaml` is required. Install it before reading EPM configuration.")
  }

  if (!.epm_is_scalar_character(path)) {
    .epm_abort("`path` must be a non-empty character string.")
  }

  if (!file.exists(path)) {
    .epm_abort(sprintf("YAML file not found: %s", path))
  }

  out <- yaml::read_yaml(path)

  if (!is.list(out)) {
    .epm_abort(sprintf("YAML file must parse to a list: %s", path))
  }

  out
}

epm_config_path <- function(file) {
  if (!.epm_is_scalar_character(file)) {
    .epm_abort("`file` must be a non-empty character string.")
  }

  path <- file.path(epm_project_root(), "config", file)

  if (!file.exists(path)) {
    .epm_abort(sprintf("Configuration file not found: %s", path))
  }

  normalizePath(path, winslash = "/", mustWork = TRUE)
}

epm_load_config <- function(config_dir = "config") {
  if (!.epm_is_scalar_character(config_dir)) {
    .epm_abort("`config_dir` must be a non-empty character string.")
  }

  config_dir <- if (grepl("^([A-Za-z]:)?[/\\\\]", config_dir)) {
    config_dir
  } else {
    file.path(epm_project_root(), config_dir)
  }

  files <- c(
    paths = "paths.yml",
    periods = "periods.yml",
    domains = "domains.yml",
    indicators = "indicators.yml"
  )

  config <- lapply(files, function(file) {
    epm_read_yaml(file.path(config_dir, file))
  })

  config$config_dir <- normalizePath(config_dir, winslash = "/", mustWork = TRUE)
  epm_check_required_config(config, names(files))
  config
}

epm_get_config_value <- function(config, path, default = NULL) {
  if (is.character(path) && length(path) == 1L) {
    path <- strsplit(path, ".", fixed = TRUE)[[1]]
  }

  if (!is.character(path) || length(path) == 0L) {
    .epm_abort("`path` must be a character vector or a dot-separated string.")
  }

  value <- config

  for (node in path) {
    if (!is.list(value) || is.null(value[[node]])) {
      return(default)
    }
    value <- value[[node]]
  }

  value
}

epm_check_required_config <- function(config, required_names) {
  if (!is.list(config)) {
    .epm_abort("`config` must be a list.")
  }

  missing <- setdiff(required_names, names(config))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Missing required configuration section(s): %s",
      paste(missing, collapse = ", ")
    ))
  }

  invisible(TRUE)
}
