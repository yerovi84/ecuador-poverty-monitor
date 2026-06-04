epm_find_project_root <- function() {
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
      stop("Could not find project root containing `_quarto.yml` and `config/`.", call. = FALSE)
    }

    current <- parent
  }
}

epm_run_step <- function(script) {
  if (!file.exists(script)) {
    stop(sprintf("Build step not found: %s", script), call. = FALSE)
  }

  message(sprintf("==> Running %s", script))

  rscript <- if (identical(.Platform$OS.type, "windows")) {
    file.path(R.home("bin"), "Rscript.exe")
  } else {
    file.path(R.home("bin"), "Rscript")
  }

  status <- system2(
    rscript,
    args = script,
    stdout = "",
    stderr = ""
  )

  if (!identical(status, 0L)) {
    stop(sprintf("Build stopped because `%s` failed with status %s.", script, status), call. = FALSE)
  }

  message(sprintf("<== Completed %s", script))
  invisible(TRUE)
}

project_root <- epm_find_project_root()
setwd(project_root)

steps <- c(
  "scripts/00_install_requirements.R",
  "scripts/00_setup.R",
  "scripts/01_build_monthly_pulse.R",
  "scripts/02_build_quarterly_view.R",
  "scripts/03_build_annual_core.R",
  "scripts/04_build_site_metadata.R"
)

for (step in steps) {
  epm_run_step(step)
}

message("EPM structural build completed successfully.")
message(sprintf("Steps completed: %s", paste(steps, collapse = " -> ")))
message("No Quarto render was run by this script.")
