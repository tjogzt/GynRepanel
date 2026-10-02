# MDD + Equivalence 双门判定四分类器
# Dual-gate classifier based on Minimum Detectable Difference + equivalence

#' Undecidable Four-Way Classification (MDD + Equivalence)
#'
#' 基于 MDD（最小可检测差异，纯度门 G2）与等价边界（equivalence gate）的双门判定，
#' 返回 c("superior","equivalent","undecidable","inferior") 四分类之一。
#' Dual-gate classification using MDD (Minimum Detectable Difference, purity gate
#' G2) and an equivalence bound. Returns one of
#' c("superior","equivalent","undecidable","inferior").
#'
#' @param diff 观测效应量（相对于参考或基准）。
#'   Observed effect size (vs. reference / baseline).
#' @param mdd  最小可检测差异（MDD，非负）。
#'   Minimum Detectable Difference (non-negative).
#' @param equiv 等价下界（对称上界为 -equiv，因此需 equiv < 0）。
#'   Lower equivalence bound; symmetric upper bound is \code{-equiv},
#'   so \code{equiv} must be negative.
#'
#' @return 长度为1的字符向量，取值：
#'   \describe{
#'     \item{superior}{\code{diff > mdd} 且 \code{diff > -equiv}。}
#'     \item{inferior}{\code{diff < -mdd} 且 \code{diff < equiv}。}
#'     \item{equivalent}{\code{equiv < diff < -equiv}（完全落入等价区间）。}
#'     \item{undecidable}{其余情况：无法判优/判劣/判等价。}
#'   }
#'
#' @export
undecidable_classify <- function(diff, mdd, equiv) {
  stopifnot(is.numeric(diff), length(diff) == 1L, is.finite(diff))
  stopifnot(is.numeric(mdd),  length(mdd)  == 1L, is.finite(mdd),  mdd >= 0)
  stopifnot(is.numeric(equiv), length(equiv) == 1L, is.finite(equiv), equiv < 0)

  equiv_upper <- -equiv

  if (diff > mdd && diff > equiv_upper) {
    return("superior")
  }
  if (diff < -mdd && diff < equiv) {
    return("inferior")
  }
  if (diff > equiv && diff < equiv_upper) {
    return("equivalent")
  }
  "undecidable"
}
