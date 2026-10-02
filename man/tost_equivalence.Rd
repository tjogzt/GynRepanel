\name{tost_equivalence}
\alias{tost_equivalence}
\title{TOST Equivalence Test (Two One-Sided Tests)}
\usage{
tost_equivalence(x, delta_equiv = 0.10, alpha = 0.05)
}
\arguments{
  \item{x}{Numeric vector of differences or single-sample measurements.
    数值向量（差分或单样本测量）。}
  \item{delta_equiv}{Symmetric equivalence threshold; defaults to 0.10 (10\%).
    等价阈值（对称边界），默认 0.10（10\%）。}
  \item{alpha}{Significance level; defaults to 0.05.
    显著性水平，默认 0.05。}
}
\value{
A list with entries:
  \describe{
    \item{neg_p}{One-sided p-value for H0: mu <= -delta_equiv.
      H0: μ ≤ -Δequiv 的单侧 p 值。}
    \item{pos_p}{One-sided p-value for H0: mu >= +delta_equiv.
      H0: μ ≥ +Δequiv 的单侧 p 值。}
    \item{tost_p}{Combined TOST p-value = max(neg_p, pos_p).
      TOST 合并 p 值 = max(neg_p, pos_p)。}
    \item{ci_90_low}{Lower bound of the 90\% confidence interval.
      90\% 置信区间下限。}
    \item{ci_90_high}{Upper bound of the 90\% confidence interval.
      90\% 置信区间上限。}
    \item{equivalent}{Logical: whether the 90\% CI lies strictly within
      (-delta_equiv, +delta_equiv).
      逻辑值：ci_90 是否完全落入 (-Δequiv, +Δequiv)。}
  }
}
\description{
Performs Two One-Sided Tests (TOST) on a one-sample or paired-difference vector.
对单样本或成对差分向量执行双单侧等价检验，默认等价边界 Δequiv = ±10\%。
}
