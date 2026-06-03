#!/usr/bin/env bash
# =============================================================================
# 02_run_sarek_strelka2.sh — Launch nf-core/Sarek with Strelka2
# Author: Meryem Fellah | Sequentia Biotech 2025
#
# Runs the full Sarek germline pipeline (BWA-MEM → MarkDuplicates → BQSR →
# Strelka2) for all 7 GIAB samples on chromosome 22.
#
# Strelka2 algorithm:
#   1. Tiered haplotype model:
#      - Tier 1: rapid evaluation for simple/common sites
#      - Tier 2: micro-assembly triggered only for complex indels and loci
#   2. Empirical Variant Scoring (EVS) for final variant scoring:
#      - A machine learning model integrating:
#        depth (DP), allele frequency, strand bias, base quality
#      - EVS trained to maximize precision while maintaining high sensitivity
#   This design makes Strelka2 both fast and well-calibrated for germline calls.
#
# Results in our benchmark:
#   More balanced performance than DeepVariant
#   Closer to the main manual-run cluster in precision/recall space
#   Outperforms BCFtools in both precision and recall
#   Slightly behind GATK and FreeBayes for SNP recall
#
# Runtime note:
#   Strelka2 is significantly faster than DeepVariant.
#   All 7 samples typically complete in 2–4 hours on 30 threads.
#
# Usage: bash 02_run_sarek_strelka2.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLESHEET="/media/sequentia/sdb1/visitor3/sarek/samplesheets/samplesheet_giab_all.csv"
CONFIG="${SCRIPT_DIR}/../../config/sarek_strelka2.config"
OUTDIR="/media/sequentia/sdb1/visitor3/process/sarek/strelka2"
LOG="${OUTDIR}/nextflow_run.log"

mkdir -p "${OUTDIR}"

echo "=============================================="
echo "  Sarek + Strelka2 — all GIAB samples"
echo "  Caller   : strelka"
echo "  Interval : chr22"
echo "  Samplesheet : ${SAMPLESHEET}"
echo "  Config      : ${CONFIG}"
echo "  Output      : ${OUTDIR}"
echo "  Log         : ${LOG}"
echo "=============================================="

if ! command -v nextflow &> /dev/null; then
    echo "[ERROR] Nextflow not found. Install with:"
    echo "  curl -s https://get.nextflow.io | bash"
    exit 1
fi

if [[ ! -f "${SAMPLESHEET}" ]]; then
    echo "[ERROR] Samplesheet not found: ${SAMPLESHEET}"
    echo "  Run scripts/preparation/01_build_samplesheet.sh first."
    exit 1
fi

nextflow run nf-core/sarek \
    -revision 3.5.1 \
    -profile docker \
    -c "${CONFIG}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    --genome null \
    --fasta /media/sequentia/sdb1/visitor3/reference/Homo_sapiens.GRCh38.dna.toplevel.fa \
    --tools strelka \
    --intervals chr22 \
    --trim_fastq false \
    -resume \
    2>&1 | tee "${LOG}"

echo ""
echo "=============================================="
echo "  Sarek + Strelka2 run complete."
echo "  VCF outputs: ${OUTDIR}/variant_calling/strelka/"
echo "  MultiQC    : ${OUTDIR}/multiqc/multiqc_report.html"
echo "  Full log   : ${LOG}"
echo "=============================================="
