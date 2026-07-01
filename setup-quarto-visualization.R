source(file.path(PROJ_DIR, "notebooks/utils.R"))
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))
tryCatch(hgd_url(), error = function(e) { library(httpgd); hgd() })