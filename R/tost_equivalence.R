# TOST 双单侧等价检验 — Two One-Sided Tests for equivalence
# Δequiv 默认 10%（0.10），可根据场景自定义
# Δequiv defaults to 10% (0.10), configurable per use case

#' TOST Equivalence Test (Two One-Sided Tests)
#'
#' 对单样本或成对差分向量执行双单侧等价检验，默认等价边界 Δequiv = ±10%。
#' Performs Two One-Sided Tests (TOST) on a one-sample or paired-difference
#' vector with default equivalence bounds Δequiv = ±10%.
#'
#' @param x 数值向量（差分或单样本测量）。
#'   Numeric vector of differences or single-sample measurements.
#' @param delta_equiv 等价阈值（对称边界），默认0.10（10%）。
#'   Symmetric equivalence threshold; defaults to 0.10 (10%).
#' @param alpha 显著性水平，默认0.05。
#'   Significance level; defaults to 0.05.
#'
#' @return \code{list(neg_p, pos_p, tost_p, ci_90_low, ci_90_high, equivalent)}
#'   \describe{
#'     \item{neg_p}{H0: μ ≤ -Δequiv 的单侧 p 值。}
#'     \item{pos_p}{H0: μ ≥ +Δequiv 的单侧 p 值。}
#'     \item{tost_p}{TOST 合并 p 值 = max(neg_p, pos_p)。}
#'     \item{ci_90_low}{90% 置信区间下限。}
#'     \item{ci_90_high}{90% 置信区间上限。}
#'     \item{equivalent}{逻辑值：ci_90 是否完全落入 (-Δequiv, +Δequiv)。}
#'   }
#'
#' @export
tost_equivalence <- function(x, delta_equiv = 0.10, alpha = 0.05) {
  stopifnot(is.numeric(x), length(na.omit(x)) >= 2L,
            is.numeric(delta_equiv), delta_equiv > 0,
            is.numeric(alpha), alpha > 0, alpha < 1)

  x <- x[is.finite(x)]
  n <- length(x)
  x_bar <- mean(x)
  s <- sd(x)
  se <- s / sqrt(n)

  t_neg <- (x_bar - (-delta_equiv)) / se
  t_pos <- (x_bar - delta_equiv) / se

  neg_p <- stats::pt(t_neg, df = n - 1L, lower.tail = FALSE)
  pos_p <- stats::pt(t_pos, df = n - 1L, lower.tail = TRUE)
  tost_p <- max(neg_p, pos_p)

  q <- stats::qt(1 - alpha, df = n - 1L)
  ci_90_low  <- x_bar - q * se
  ci_90_high <- x_bar + q * se

  equivalent <- (ci_90_low > -delta_equiv) && (ci_90_high < delta_equiv)

  list(neg_p = unname(neg_p),
       pos_p = unname(pos_p),
       tost_p = unname(tost_p),
       ci_90_low = unname(ci_90_low),
       ci_90_high = unname(ci_90_high),
       equivalent = unname(equivalent))
}
