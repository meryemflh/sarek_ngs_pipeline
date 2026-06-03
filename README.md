# Sarek NGS Pipeline — Germline Variant Calling

**End-to-end germline variant calling using nf-core/Sarek**  
Automated benchmark runs for: BWA-MEM + DeepVariant and BWA-MEM + Strelka2  

---

## Overview

This repository contains all configuration files, samplesheets, and analysis scripts used to run the **nf-core/Sarek pipeline (v3.5.1)** as part of a systematic benchmarking study.

Sarek was run in parallel with manual pipelines (BWA/HISAT2/Minimap2 + GATK/FreeBayes/BCFtools) to evaluate:
- How **automated best-practice pipelines** compare to **manually configured workflows** in terms of precision and recall
- The performance of **DeepVariant** (deep learning CNN-based caller) vs **Strelka2** (probabilistic tiered caller)
- The impact of **default pipeline parameters** vs **manually tuned parameters** on variant calling outcomes

All runs used **7 GIAB samples (HG001–HG007)**, chromosome 22, aligned to **GRCh38**.

---

## What is Sarek?

[nf-core/Sarek](https://nf-co.re/sarek) is an open-source Nextflow pipeline for whole-genome germline and somatic variant calling, developed by the nf-core community. It integrates:

- **Mapping:** BWA-MEM (default)
- **Post-processing:** MarkDuplicates, BQSR
- **Variant calling:** GATK HaplotypeCaller, DeepVariant, Strelka2, Mutect2
- **QC:** FastQC, MultiQC, Qualimap
- **Containers:** Docker / Singularity for full reproducibility

In this study, we used **DeepVariant** and **Strelka2** as variant callers, since they represent two complementary and well-validated approaches within the Sarek framework.

---

## Key Difference: Sarek vs Manual Parameters

Sarek's BWA-MEM uses **different default parameters** from our manual runs:

| Parameter | Manual runs | Sarek default |
|-----------|-------------|---------------|
| Seed length `-k` | 21 | 19 |
| Mismatch penalty `-B` | 6 | 4 |
| Gap open `-O` | 5,5 | 6 |
| Gap extension `-E` | 3,3 | 1 |

This difference is intentional — it mirrors the real-world scenario where pipeline developers optimize defaults independently of individual researchers. Comparing both settings allows us to assess how much **parameter encapsulation** influences downstream variant calling performance.

---

## Repository Structure

```
sarek-ngs-pipeline/
├── samplesheets/
│   ├── samplesheet_giab_all.csv     ← full samplesheet (HG001–HG007)
│   └── samplesheet_HG001.csv        ← single-sample example
├── config/
│   ├── sarek_deepvariant.config     ← Nextflow config for DeepVariant run
│   ├── sarek_strelka2.config        ← Nextflow config for Strelka2 run
│   └── resources.config             ← HPC resource definitions
├── scripts/
│   ├── preparation/
│   │   └── 01_build_samplesheet.sh  ← auto-generates samplesheet from FASTQ dir
│   └── analysis/
│       ├── 01_run_sarek_deepvariant.sh
│       ├── 02_run_sarek_strelka2.sh
│       └── 03_evaluate_results.sh   ← hap.py evaluation on Sarek VCF outputs
├── docs/
│   └── sarek_pipeline_notes.md      ← detailed run notes and observations
└── results/                          ← output directory (not tracked by git)
```

---

## Pipeline Overview

```
Raw FASTQ (HG001–HG007, paired-end Illumina, chr22)
        │
        ▼
  nf-core/Sarek v3.5.1
        │
        ├── [1] FastQC (raw QC)
        ├── [2] Trim Galore (adapter trimming)
        ├── [3] BWA-MEM (default Sarek params: -k 19 -B 4 -O 6 -E 1)
        ├── [4] SAMtools sort + index
        ├── [5] GATK MarkDuplicates
        ├── [6] GATK BQSR (dbSNP + Mills + 1000G)
        ├── [7a] DeepVariant  → HG00X_deepvariant.vcf.gz
        ├── [7b] Strelka2     → HG00X_strelka2.vcf.gz
        └── [8] MultiQC report
        │
        ▼
  hap.py evaluation vs GIAB truth sets
        │
        ▼
  Precision / Recall per sample
```

---

## Variant Callers

### DeepVariant (Google)
DeepVariant transforms aligned reads into **pileup images** encoding base quality, mapping quality, strand orientation, and read position. A **convolutional neural network (CNN)** trained on GIAB truth sets classifies each candidate variant as real or artifact.

- **Strength:** High recall, excellent SNP and indel detection in complex regions
- **Profile in our study:** High recall (~0.99) but lower precision (~0.91–0.93) — more permissive, more false positives
- **Best use case:** Exploratory analyses, maximizing detection

### Strelka2 (Illumina)
Strelka2 uses a **tiered haplotype model**: rapid evaluation for simple sites, micro-assembly only when necessary. Indel and complex variant scoring uses **Empirical Variant Scoring (EVS)**, a machine learning model integrating depth, allele frequency, and strand bias.

- **Strength:** Fast, balanced precision and recall, reliable for both germline and somatic
- **Profile in our study:** More balanced performance, closer to the main manual-run cluster
- **Best use case:** Standard germline calling with good precision/recall balance

---

## Samples

| Sample | Background | Kraken2 (% human) |
|--------|------------|-------------------|
| HG001 | NA12878, Ashkenazi Jewish (F) | 81.88% |
| HG002 | NA24385, Ashkenazi Jewish (M) | — |
| HG003 | NA24149, HG002 father | — |
| HG004 | NA24143, HG002 mother | — |
| HG005 | NA24631, Chinese-American (M) | 94.46% |
| HG006 | NA24694, Chinese-American (F) | — |
| HG007 | NA24695, Chinese-American (M) | — |

HG002–HG004 and HG005–HG007 form two family trios.  
All aligned to **GRCh38 (unmasked)**, chromosome 22 only.

---

## How to Run

### Requirements
- Nextflow ≥ 22.10.6
- Docker or Singularity
- ≥ 32 CPU threads, ≥ 64 GB RAM recommended

### 1. Build samplesheet
```bash
bash scripts/preparation/01_build_samplesheet.sh
```

### 2. Run DeepVariant
```bash
bash scripts/analysis/01_run_sarek_deepvariant.sh
```

### 3. Run Strelka2
```bash
bash scripts/analysis/02_run_sarek_strelka2.sh
```

### 4. Evaluate with hap.py
```bash
bash scripts/analysis/03_evaluate_results.sh
```

---

## Key Results Summary

| Pipeline | Caller | SNP Precision | SNP Recall | Indel Precision | Indel Recall |
|----------|--------|---------------|------------|-----------------|--------------|
| BWA (Sarek) | DeepVariant | ~0.91–0.93 | ~0.99 | high | high |
| BWA (Sarek) | Strelka2 | moderate-high | competitive | moderate | moderate |
| BWA (manual) | GATK | highest | high | high | moderate |

**Main finding:** Sarek's automated workflows are reliable and reproducible but do not consistently outperform manually tuned combinations. BWA + Strelka2 offers the best balance within Sarek. DeepVariant maximizes recall but at a precision cost.

---

## Software Versions

| Tool | Version |
|------|---------|
| nf-core/Sarek | 3.5.1 |
| Nextflow | 22.10.6 |
| BWA-MEM | 0.7.17 |
| DeepVariant | 1.5.0 |
| Strelka2 | 2.9.10 |
| GATK | 4.2 (MarkDuplicates + BQSR) |
| hap.py | 0.3.14 |
| Docker / Singularity | (managed by Sarek) |

---

## Related Repository

See also: [ngs-benchmarking](https://github.com/meryemflh/ngs_benchmarking) — Manual pipeline benchmarking (BWA/HISAT2/Minimap2 × GATK/FreeBayes/BCFtools)

---

## Author

**Meryem Fellah** — Bioinformatics Engineer  
École Supérieure Mohammed IV d'Ingénieurs en Sciences de la Santé  
Internship: Sequentia Biotech, Barcelona 
Supervisor: Dr. Matteo Schiavinato
