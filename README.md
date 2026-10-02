# GynRepanel

> 妇科恶性肿瘤多组学跨队列整合基准工具箱
> Gynecologic Multi-Omic Cross-Cohort Integration Benchmark

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://img.shields.io/badge/R%20CMD%20check-PASS%20%7C%20ERROR%3D0%20WARN%3D0%20NOTE%3D1-brightgreen)](https://github.com/tjogzt/GynRepanel/actions)
[![Zenodo DOI](https://img.shields.io/badge/Zenodo-DOI_Pending-blue)](https://zenodo.org/)

---

## 许可证声明 | License

本项目采用 **MIT License** 开源发布。完整许可文本见 `LICENSE` 文件。

This project is released under the **MIT License**. See the `LICENSE` file for the full license text.

```
MIT License

Copyright (c) 2026 TJ OGZT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 安装说明 | Installation

### 中文安装指南

#### 方式一：通过 GitHub 直接安装（推荐）

确保已安装 R（≥ 4.2.0）及 `devtools` 包，然后在 R 控制台执行：

```r
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

devtools::install_github("tjogzt/GynRepanel", dependencies = TRUE)
```

#### 方式二：通过 CRAN 三步安装

1. **第一步**：安装依赖包
   ```r
   install.packages(c("SNFtool", "mixOmics", "knitr", "rmarkdown", "testthat", "pdftools"))
   ```

2. **第二步**：安装 Bioconductor 依赖
   ```r
   if (!requireNamespace("BiocManager", quietly = TRUE)) {
     install.packages("BiocManager")
   }
   BiocManager::install(c("MOFA2", "iClusterPlus"))
   ```

3. **第三步**：从本地源码包安装
   ```r
   install.packages("GynRepanel_0.1.0.tar.gz", repos = NULL, type = "source")
   ```

---

### English Installation Guide

#### Method 1: Install Directly from GitHub (Recommended)

Ensure R (≥ 4.2.0) and the `devtools` package are installed, then run in the R console:

```r
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

devtools::install_github("tjogzt/GynRepanel", dependencies = TRUE)
```

#### Method 2: CRAN-Style Three-Step Installation

1. **Step 1**: Install CRAN dependencies
   ```r
   install.packages(c("SNFtool", "mixOmics", "knitr", "rmarkdown", "testthat", "pdftools"))
   ```

2. **Step 2**: Install Bioconductor dependencies
   ```r
   if (!requireNamespace("BiocManager", quietly = TRUE)) {
     install.packages("BiocManager")
   }
   BiocManager::install(c("MOFA2", "iClusterPlus"))
   ```

3. **Step 3**: Install from local source tarball
   ```r
   install.packages("GynRepanel_0.1.0.tar.gz", repos = NULL, type = "source")
   ```

---

## 快速上手 | Quick Start

### 中文示例

```r
library(GynRepanel)

# 运行空壳基准（无数据输入，返回占位结构）
result <- runGynBenchmark()

# 查看输出结构
str(result$arimats)     # 22×8 ARI 矩阵（CV折叠 × 方法）
str(result$metrics)     # 指标集合（PAC / Fiedler gap / G2 纯度门等）
```

### English Example

```r
library(GynRepanel)

# Run skeleton benchmark (no data input, returns placeholder structure)
result <- runGynBenchmark()

# Inspect output structure
str(result$arimats)     # 22×8 ARI matrix (CV folds × methods)
str(result$metrics)     # Metrics bundle (PAC / Fiedler gap / G2 purity gate, etc.)
```

---

## NRCR 可复现性提示语 | NRCR Reproducibility Notice

> ⚠️ **NRCR-20 可复现性架构（Negative-marginal Reproducibility Cohort Reference, 20 items）**
>
> 本基准结果的解读受限于以下20项 NRCR 约束：
> 1. 跨平台批次效应（EEEC vs CPTAC）未被全部吸收
> 2. 蛋白质桥接层（TCPA RPPA）存在 MD5 漂移
> 3. 最小可检测差异（MDD）≥ 效应量导致 **负边际价值** 判定
> 4. RAINBO 校准下 ProMisE/CN_LOW 亚型仍存在误校准
> 5. 算法不可判定性（Undecidability）：8种方法跨折叠的一致性 < Cohen's κ = 0.4
>
> 详细 NRCR-20 清单请见 `vignettes/GynRepanel-intro.Rmd` 及补充材料。

> ⚠️ **NRCR-20 Reproducibility Scaffold (Negative-marginal Reproducibility Cohort Reference, 20 items)**
>
> Interpretation of this benchmark is bounded by the following 20 NRCR constraints:
> 1. Cross-platform batch effects (EEEC vs CPTAC) are not fully absorbed
> 2. Protein bridge layer (TCPA RPPA) exhibits MD5-level version drift
> 3. Minimum Detectable Difference (MDD) ≥ effect size ⇒ **Negative Marginal Value** verdict
> 4. ProMisE/CN_LOW subtyping remains mis-calibrated under RAINBO calibration
> 5. Algorithmic Undecidability: cross-fold agreement among 8 methods < Cohen's κ = 0.4
>
> Full NRCR-20 checklist is available in `vignettes/GynRepanel-intro.Rmd` and the Supplementary Information.

---

## 引用信息 | Citation

如果您在研究中使用了 GynRepanel，请引用：

If you use GynRepanel in your research, please cite:

```bibtex
@software{tjogzt2026gynrepanel,
  author       = {TJ OGZT and
                  HexaStar Six-View Consortium},
  title        = {GynRepanel: Gynecologic Multi-Omic Cross-Cohort Benchmark},
  month        = oct,
  year         = 2026,
  publisher    = {Zenodo},
  version      = {0.1.0},
  doi          = {10.5281/zenodo.PENDING},
  url          = {https://github.com/tjogzt/GynRepanel}
}
```

CFF 格式引用文件见 `CITATION.cff`。

For CFF format citation, see `CITATION.cff`.

---

## 项目链接 | Links

- **GitHub 仓库 / Repository**: https://github.com/tjogzt/GynRepanel
- **Bug 反馈 / Bug Reports**: https://github.com/tjogzt/GynRepanel/issues
- **Zenodo 存档 / Zenodo Archive**: DOI Pending

---

*Package version 0.1.0 | Released 2026-10-02*
