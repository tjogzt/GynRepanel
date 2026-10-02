\name{undecidable_classify}
\alias{undecidable_classify}
\title{Undecidable Four-Way Classification (MDD + Equivalence)}
\usage{
undecidable_classify(diff, mdd, equiv)
}
\arguments{
  \item{diff}{Observed effect size (vs. reference / baseline).
    观测效应量（相对于参考或基准）。}
  \item{mdd}{Minimum Detectable Difference (non-negative).
    最小可检测差异（MDD，非负）。}
  \item{equiv}{Lower equivalence bound; symmetric upper bound is -equiv.
    等价下界（对称上界为 -equiv，因此需 equiv < 0）。}
}
\value{
A length-1 character vector, one of:
  \describe{
    \item{superior}{diff > mdd AND diff > -equiv.}
    \item{inferior}{diff < -mdd AND diff < equiv.}
    \item{equivalent}{equiv < diff < -equiv (wholly inside equivalence band).}
    \item{undecidable}{Otherwise: cannot declare superiority, inferiority,
      nor equivalence.}
  }
对应中文：
  c("superior","equivalent","undecidable","inferior") 四分类之一。
}
\description{
Dual-gate classifier using MDD (purity gate G2) and an equivalence bound.
基于 MDD（最小可检测差异，纯度门 G2）与等价边界（equivalence gate）的双门判定。
}
