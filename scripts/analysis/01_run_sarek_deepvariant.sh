#!/usr/bin/env bash
# =============================================================================
# 01_run_sarek_deepvariant.sh — Launch nf-core/Sarek with DeepVariant
# Author: Meryem Fellah | Sequentia Biotech 2025
#
# Runs the full Sarek germline pipeline (BWA-MEM → MarkDuplicates → BQSR →
# DeepVariant) for all 7 GIAB samples on chromosome 22.
#
# DeepVariant algorithm:
#   1. Converts BAM pileups into multi-channel images (base quality,
#      mapping quality, strand, read position encoded as pixel values)
#   2. A convolutional neural network (CNN) trained on GIAB truth sets
#      classifies each candidate position as: homozygous ref / het / hom alt
#   This deep learning approach captures complex patterns that traditional
#   statistical models miss, particularly in low-complexity regions.
#
# Results in our benchmark:
#   SNP recall   ~0.99 (highest of all callers tested)
#   SNP precision ~0.91–0.93 (lower than GATK — more permissive, more FP)
#
# Runtime note:
#   DeepVariant is CPU-intensive. On 30 threads / 128 GB RAM it takes
#   approximately 4–8 hours per sample. GPU acceleration is not available
#   on the student server — CPU mode is used.
#
# Logs: results/sarek/deepvariant/pipeline_info/
#
# Usage: bash 01_run_sarek_deepvariant.sh
# =============================================================================

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLESHEET="/media/sequentia/sdb1/visitor3/sarek/samplesheets/samplesheet_giab_all.csv"
CONFIG="${SCRIPT_DIR}/../../config/sarek_deepvariant.config"
OUTDIR="/media/sequentia/sdb1/visitor3/process/sarek/deepvariant"
LOG="${OUTDIR}/nextflow_run.log"

mkdir -p "${OUTDIR}"

echo "=============================================="
echo "  Sarek + DeepVariant — all GIAB samples"
echo "  Caller   : deepvariant"
echo "  Interval : chr22"
echo "  Samplesheet : ${SAMPLESHEET}"
echo "  Config      : ${CONFIG}"
echo "  Output      : ${OUTDIR}"
echo "  Log         : ${LOG}"
echo "=============================================="

# ── Check prerequisites ───────────────────────────────────────────────────────
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

# ── Run Sarek ─────────────────────────────────────────────────────────────────
nextflow run nf-core/sarek \
    -revision 3.5.1 \
    -profile docker \
    -c "${CONFIG}" \
    --input "${SAMPLESHEET}" \
    --outdir "${OUTDIR}" \
    --genome null \
    --fasta /media/sequentia/sdb1/visitor3/reference/Homo_sapiens.GRCh38.dna.toplevel.fa \
    --tools deepvariant \
    --intervals chr22 \
    --trim_fastq false \
    -resume \
    2>&1 | tee "${LOG}"

echo ""
echo "=============================================="
echo "  Sarek + DeepVariant run complete."
echo "  VCF outputs: ${OUTDIR}/variant_calling/deepvariant/"
echo "  MultiQC    : ${OUTDIR}/multiqc/multiqc_report.html"
echo "  Full log   : ${LOG}"
echo "=============================================="
