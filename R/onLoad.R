.onAttach <- function(libname, pkgname) {
  pkg_ver <- tryCatch(as.character(utils::packageVersion("GynRepanel")),
                      error = function(e) "0.0.0")
  int_ver <- if (requireNamespace("intNMFequiv", quietly = TRUE)) {
    as.character(utils::packageVersion("intNMFequiv"))
  } else {
    "NOT_INSTALLED"
  }
  mcia_ver <- if (requireNamespace("MCIAequiv", quietly = TRUE)) {
    as.character(utils::packageVersion("MCIAequiv"))
  } else {
    "NOT_INSTALLED"
  }
  msg <- sprintf(
    "GynRepanel %s attached. Equivalence packages: intNMFequiv=%s, MCIAequiv=%s. See NRCR report at results/docs/.",
    pkg_ver, int_ver, mcia_ver
  )
  packageStartupMessage(msg)
}

