project_root <- {
  current <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  repeat {
    if (
      file.exists(file.path(current, "_quarto.yml")) &&
        dir.exists(file.path(current, "config"))
    ) {
      break
    }

    parent <- dirname(current)

    if (identical(parent, current)) {
      stop("Could not find project root containing `_quarto.yml` and `config/`.", call. = FALSE)
    }

    current <- parent
  }

  current
}

setwd(project_root)

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop(
    "Package `yaml` is required for EPM configuration. ",
    "Run `Rscript scripts/00_install_requirements.R` before setup.",
    call. = FALSE
  )
}

utils <- list.files("R", pattern = "^utils-.*\\.R$", full.names = TRUE)

if (length(utils) == 0L) {
  stop("No utility files found under R/utils-*.R.", call. = FALSE)
}

invisible(lapply(sort(utils), source))

config <- epm_load_config()

required_dirs <- config$paths$validation$required_directories

if (is.character(required_dirs)) {
  invisible(lapply(file.path(epm_project_root(), required_dirs), epm_make_dir))
}

epm_validate_all_configs(config)
epm_assert_no_raw_microdata_tracked()
epm_prepare_derived_dirs(config$paths)
epm_smoke_test_config()

message("EPM setup complete: configuration loaded, contracts validated, derived directories ready.")
