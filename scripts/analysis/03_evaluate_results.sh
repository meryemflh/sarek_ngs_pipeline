#!/usr/bin/env bash
# =============================================================================
# 03_evaluate_results.sh — hap.py precision/recall evaluation on Sarek VCFs
# Author: Meryem Fellah | Sequentia Biotech 2025
#
# Evaluates Sarek variant calling outputs (DeepVariant and Strelka2) against
# GIAB truth sets using hap.py, under the same conditions as manual runs:
#   - Same reference genome (GRCh38)
#   - Same high-confidence BED regions (GIAB)
#   - Same chromosome restriction (chr22)
#
# This ensures that the comparison between Sarek and manual runs is fair and
# directly interpretable: any difference in precision/recall is due to the
# tool behavior and pipeline configuration, not to evaluation methodology.
#
# Sarek output VCF locations:
#   DeepVariant: <outdir>/variant_calling/deepvariant/<sample>/<sample>.vcf.gz
#   Strelka2   : <outdir>/variant_calling/strelka/<sample>/<sample>.variants.vcf.gz
#
# Usage: bash 03_evaluate_results.sh
# =============================================================================

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR="/media/sequentia/sdb1/visitor3"
REFERENCE="${BASE_DIR}/reference/Homo_sapiens.GRCh38.dna.toplevel.fa"
GIAB_DIR="${BASE_DIR}/databases/GIAB"
EVAL_DIR="${BASE_DIR}/process/evaluation/sarek"
SAREK_DV_DIR="${BASE_DIR}/process/sarek/deepvariant/variant_calling/deepvariant"
SAREK_S2_DIR="${BASE_DIR}/process/sarek/strelka2/variant_calling/strelka"
SAMPLES=(HG001 HG002 HG003 HG004 HG005 HG006 HG007)
REGION="chr22"

mkdir -p "${EVAL_DIR}"

# ── Aggregated results file ───────────────────────────────────────────────────
RESULTS="${EVAL_DIR}/sarek_precision_recall.tsv"
echo -e "Sample\tPipeline\tCaller\tType\tTP\tFP\tFN\tPrecision\tRecall" > "${RESULTS}"

# ── Function: run hap.py ──────────────────────────────────────────────────────
run_happy() {
    local SAMPLE="$1"
    local CALLER="$2"      # deepvariant | strelka2
    local TEST_VCF="$3"

    local TRUTH_VCF="${GIAB_DIR}/${SAMPLE}/${SAMPLE}_truth.vcf.gz"
    local TRUTH_BED="${GIAB_DIR}/${SAMPLE}/${SAMPLE}_confident.bed"
    local OUT_PREFIX="${EVAL_DIR}/${SAMPLE}_sarek_${CALLER}"

    if [[ ! -f "${TEST_VCF}" ]]; then
        echo "[SKIP] VCF not found for ${SAMPLE}|${CALLER}: ${TEST_VCF}"
        return
    fi

    if [[ ! -f "${TRUTH_VCF}" || ! -f "${TRUTH_BED}" ]]; then
        echo "[SKIP] GIAB truth files missing for ${SAMPLE}"
        return
    fi

    echo "[${SAMPLE}|${CALLER}] Running hap.py..."
    hap.py \
        "${TRUTH_VCF}" \
        "${TEST_VCF}" \
        -f "${TRUTH_BED}" \
        -r "${REFERENCE}" \
        -o "${OUT_PREFIX}" \
        --engine=vcfeval \
        -l "${REGION}"

    echo "[${SAMPLE}|${CALLER}] Evaluation complete: ${OUT_PREFIX}.summary.csv"

    # ── Parse results ─────────────────────────────────────────────────────────
    local CSV="${OUT_PREFIX}.summary.csv"
    if [[ ! -f "${CSV}" ]]; then return; fi

    parse_row() {
        local LINE="$1"
        local TYPE="$2"
        if [[ -z "${LINE}" ]]; then return; fi
        local TP FP FN RECALL PRECISION
        TP=$(echo "${LINE}" | cut -d',' -f4)
        FN=$(echo "${LINE}" | cut -d',' -f5)
        FP=$(echo "${LINE}" | cut -d',' -f7)
        RECALL=$(echo "${LINE}" | cut -d',' -f9)
        PRECISION=$(echo "${LINE}" | cut -d',' -f10)
        echo -e "${SAMPLE}\tSarek\t${CALLER}\t${TYPE}\t${TP}\t${FP}\t${FN}\t${PRECISION}\t${RECALL}"
    }

    SNP_LINE=$(awk -F',' '/^SNP,/' "${CSV}" | head -1)
    INDEL_LINE=$(awk -F',' '/^INDEL,/' "${CSV}" | head -1)
    parse_row "${SNP_LINE}" "SNP" >> "${RESULTS}"
    parse_row "${INDEL_LINE}" "INDEL" >> "${RESULTS}"
}

# ── Evaluate all samples ──────────────────────────────────────────────────────
echo "=============================================="
echo "  hap.py evaluation — Sarek outputs"
echo "  Callers: DeepVariant + Strelka2"
echo "  Samples: ${SAMPLES[*]}"
echo "  Region : ${REGION}"
echo "=============================================="

for SAMPLE in "${SAMPLES[@]}"; do
    # DeepVariant VCF (Sarek output path)
    DV_VCF="${SAREK_DV_DIR}/${SAMPLE}/${SAMPLE}.vcf.gz"
    run_happy "${SAMPLE}" "deepvariant" "${DV_VCF}"

    # Strelka2 VCF (Sarek output path)
    S2_VCF="${SAREK_S2_DIR}/${SAMPLE}/${SAMPLE}.variants.vcf.gz"
    run_happy "${SAMPLE}" "strelka2" "${S2_VCF}"
done

echo ""
echo "=============================================="
echo "  Evaluation complete."
echo "  Results: ${RESULTS}"
echo "=============================================="
cat "${RESULTS}"
