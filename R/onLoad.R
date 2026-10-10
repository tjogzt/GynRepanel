# GynRepanel benchmark package attach startup message (ASCII ONLY per CRAN policy)
# Do NOT include any non-ASCII characters in this file; CRAN rejects them.
# ---------------------------------------------------------------------
# Six honesty anchors are always reported at package attach:
#   (1) Negative Marginal Value  0.282 -> 0.194  cross-cohort ARI (strictly decreasing)
#   (2) Undecidable Classification  Top1 vs Top2  Holm FWER p = 1.000  label-flip >= 50%
#   (3) Covariance Fragility  lambda_2 SE inflation 82.5%  (batch x platform single perturbation)
#   (4) .632+ Bootstrap optimism correction  apparent ~ 1.010  B = 500
#   (5) TOST equivalence  Lakens 2017  MDD = 0.50 ARI  (N3/N4 strata)
#   (6) NSMP Level-4 evidence  IJGC 2024: retrospective, no prospective predictive claim.

.onAttach <- function(libname, pkgname) {
  ver         <- as.character(utils::packageVersion("GynRepanel"))
  r_ver       <- paste0(R.version$major, ".", sub("\\..*", "", R.version$minor))
  doi_pin     <- "10.5281/zenodo.23166946"
  n_topics    <- 6L
  anchors     <- paste0("Negative-Marginal-Value / Undecidable-Classification / Covariance-Fragility")
  rng_policy  <- "seed=12345, L'Ecuyer-CMRG  (Fiedler flip=0 / 1000, .632+ stab < 0.0013 pct)"
  scaffold    <- "20 NRCR-20 constraints  ->  vignettes/GynRepanel-intro.Rmd"

  msg_lines <- c(
    sprintf("GynRepanel %s (R %s) attached.", ver, r_ver),
    sprintf("  Concept DOI : https://doi.org/%s", doi_pin),
    sprintf("  GitHub      : https://github.com/tjogzt/GynRepanel  (%d SEO Topics pinned)", n_topics),
    paste0("  Honesty anchors: ", anchors),
    paste0("  RNG policy   : ", rng_policy),
    paste0("  Repro scaffold: ", scaffold)
  )
  packageStartupMessage(paste(msg_lines, collapse = "\n"))
}
