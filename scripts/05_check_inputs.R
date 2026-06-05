source("scripts/00_setup.R")

epm_new_input_check <- function(check_id, check_label, status, detail, blocking) {
  data.frame(
    check_id = check_id,
    check_label = check_label,
    status = status,
    detail = detail,
    blocking = isTRUE(blocking),
    stringsAsFactors = FALSE
  )
}

epm_append_input_check <- function(diagnostic, check_id, check_label, status, detail, blocking = FALSE) {
  rbind(
    diagnostic,
    epm_new_input_check(check_id, check_label, status, detail, blocking)
  )
}

epm_check_annual_raw_layout <- function(config, raw_root) {
  diagnostic <- data.frame(
    check_id = character(),
    check_label = character(),
    status = character(),
    detail = character(),
    blocking = logical(),
    stringsAsFactors = FALSE
  )

  annual_layout <- config$paths$raw_data_layout$annual

  if (is.null(annual_layout)) {
    return(epm_append_input_check(
      diagnostic,
      "annual_layout_config",
      "Annual raw data layout",
      "missing",
      "config/paths.yml does not define raw_data_layout.annual.",
      blocking = TRUE
    ))
  }

  folder <- annual_layout$folder

  if (!.epm_is_scalar_character(folder)) {
    return(epm_append_input_check(
      diagnostic,
      "annual_layout_folder",
      "Annual raw folder contract",
      "missing",
      "raw_data_layout.annual.folder must be a non-empty string.",
      blocking = TRUE
    ))
  }

  annual_dir <- file.path(raw_root, folder)
  annual_dir_exists <- dir.exists(annual_dir)
  diagnostic <- epm_append_input_check(
    diagnostic,
    "annual_folder",
    "Annual raw folder",
    if (annual_dir_exists) "ok" else "missing",
    if (annual_dir_exists) {
      sprintf("Annual raw layer folder `%s` exists under the configured raw data root.", folder)
    } else {
      sprintf("Annual raw layer folder `%s` was not found under the configured raw data root.", folder)
    },
    blocking = !annual_dir_exists
  )

  expected_files <- annual_layout$expected_files

  if (!is.list(expected_files) || length(expected_files) == 0L) {
    return(epm_append_input_check(
      diagnostic,
      "annual_expected_files",
      "Annual expected files contract",
      "missing",
      "raw_data_layout.annual.expected_files must define at least one expected input.",
      blocking = TRUE
    ))
  }

  for (input_name in names(expected_files)) {
    input_contract <- expected_files[[input_name]]
    required <- isTRUE(input_contract$required)

    filename <- tryCatch(
      epm_expected_input_filename("annual", input_name, config$paths),
      error = function(error) NA_character_
    )

    if (!.epm_is_scalar_character(filename)) {
      diagnostic <- epm_append_input_check(
        diagnostic,
        sprintf("annual_%s_filename", input_name),
        sprintf("Annual `%s` exact filename", input_name),
        "missing",
        sprintf("Expected input `%s` must define an exact non-ambiguous filename.", input_name),
        blocking = required
      )
      next
    }

    file_path <- file.path(annual_dir, filename)
    found <- annual_dir_exists && file.exists(file_path)
    status <- if (found) "ok" else if (required) "missing" else "not_found_optional"
    detail <- if (found) {
      sprintf("Resolved exact `%s` input file: `%s`.", input_name, basename(file_path))
    } else if (required) {
      sprintf("Required exact `%s` input file was not found: `%s`.", input_name, filename)
    } else {
      sprintf("Optional exact `%s` input file was not found: `%s`.", input_name, filename)
    }

    diagnostic <- epm_append_input_check(
      diagnostic,
      sprintf("annual_%s_files", input_name),
      sprintf("Annual `%s` files", input_name),
      status,
      detail,
      blocking = required && !found
    )
  }

  diagnostic
}

diagnostic <- data.frame(
  check_id = character(),
  check_label = character(),
  status = character(),
  detail = character(),
  blocking = logical(),
  stringsAsFactors = FALSE
)

enemdu_available <- requireNamespace("enemduR", quietly = TRUE)
diagnostic <- epm_append_input_check(
  diagnostic,
  "enemduR_namespace",
  "enemduR package",
  if (enemdu_available) "ok" else "not_installed",
  if (enemdu_available) {
    "Package `enemduR` is available."
  } else {
    "Package `enemduR` is not installed. Install it explicitly before enabling real ENEMDU readers."
  },
  blocking = !enemdu_available
)

raw_env <- config$paths$environment$raw_data_root_env

if (!.epm_is_scalar_character(raw_env)) {
  diagnostic <- epm_append_input_check(
    diagnostic,
    "raw_root_env_contract",
    "Raw data root environment contract",
    "missing",
    "config/paths.yml must define environment.raw_data_root_env.",
    blocking = TRUE
  )
} else {
  raw_root <- Sys.getenv(raw_env, unset = "")

  if (!nzchar(raw_root)) {
    diagnostic <- epm_append_input_check(
      diagnostic,
      "raw_root_env",
      "Raw data root environment variable",
      "not_configured",
      sprintf("Environment variable `%s` is not set; annual raw inputs were not inspected.", raw_env),
      blocking = TRUE
    )
  } else if (!dir.exists(raw_root)) {
    diagnostic <- epm_append_input_check(
      diagnostic,
      "raw_root_path",
      "Raw data root path",
      "missing",
      sprintf("Environment variable `%s` is set, but the configured raw data root does not exist.", raw_env),
      blocking = TRUE
    )
  } else {
    diagnostic <- epm_append_input_check(
      diagnostic,
      "raw_root_path",
      "Raw data root path",
      "ok",
      sprintf("Environment variable `%s` is set and the configured raw data root exists.", raw_env),
      blocking = FALSE
    )

    diagnostic <- rbind(
      diagnostic,
      epm_check_annual_raw_layout(config, raw_root)
    )
  }
}

message("EPM annual input diagnostic:")
print(diagnostic, row.names = FALSE, right = FALSE)

blocking_checks <- diagnostic[diagnostic$blocking, , drop = FALSE]

if (nrow(blocking_checks) == 0L) {
  message("Input check complete: ready to connect annual core to real ENEMDU inputs.")
} else {
  message("Input check complete: faltan insumos para conectar annual core.")
  message(sprintf(
    "Blocking check(s): %s",
    paste(blocking_checks$check_id, collapse = ", ")
  ))
}

message("No microdata were read, copied, moved, or analyzed. No indicators were calculated.")
