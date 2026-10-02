test_that("tost_equivalence flags near-zero vector as equivalent", {
  set.seed(123)
  x <- rnorm(50, mean = 0, sd = 0.01)
  res <- tost_equivalence(x, delta_equiv = 0.10)
  expect_equal(res$equivalent, TRUE)
})

test_that("undecidable_classify returns undecidable or equivalent for null diff", {
  out <- undecidable_classify(diff = 0.0, mdd = 0.466, equiv = -0.10)
  expect_true(out %in% c("undecidable", "equivalent"))
})
