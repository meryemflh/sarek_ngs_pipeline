#!/usr/bin/env bash
# =============================================================================
# 01_build_samplesheet.sh — Auto-generate Sarek samplesheet from FASTQ directory
# Author: Meryem Fellah | Sequentia Biotech 2025
#
# Sarek requires a CSV samplesheet with these exact columns:
#   patient, sample, lane, fastq_1, fastq_2, sex, status
#
# Column definitions:
#   patient  : unique patient ID (= sample ID for germline studies)
#   sample   : sample ID
#   lane     : sequencing lane (1 if not lane-split)
#   fastq_1  : absolute path to R1 trimmed FASTQ
#   fastq_2  : absolute path to R2 trimmed FASTQ
#   sex      : XX (female) or XY (male) — affects sex chromosome calling
#   status   : 0 = normal (germline), 1 = tumor (somatic) — all 0 in this study
#
# GIAB sample sex assignments (from NIST documentation):
#   HG001 = NA12878 = female (XX)
#   HG002 = NA24385 = male   (XY)
#   HG003 = NA24149 = male   (XY) [HG002 father]
#   HG004 = NA24143 = female (XX) [HG002 mother]
#   HG005 = NA24631 = male   (XY)
#   HG006 = NA24694 = female (XX) [HG005 mother]
#   HG007 = NA24695 = male   (XY) [HG005 father]
#
# Usage: bash 01_build_samplesheet.sh
# =============================================================================

set -euo pipefail

TRIMMED_DIR="/media/sequentia/sdb1/visitor3/process/preprocessing/trimmed_reads"
OUTPUT_CSV="/media/sequentia/sdb1/visitor3/sarek/samplesheets/samplesheet_giab_all.csv"

mkdir -p "$(dirname "${OUTPUT_CSV}")"

# Write CSV header
echo "patient,sample,lane,fastq_1,fastq_2,sex,status" > "${OUTPUT_CSV}"

# Sample metadata: sample_id, sex
declare -A SEX=(
    [HG001]="XX"
    [HG002]="XY"
    [HG003]="XY"
    [HG004]="XX"
    [HG005]="XY"
    [HG006]="XX"
    [HG007]="XY"
)

for SAMPLE in HG001 HG002 HG003 HG004 HG005 HG006 HG007; do
    R1="${TRIMMED_DIR}/${SAMPLE}_R1_trimmed.fastq.gz"
    R2="${TRIMMED_DIR}/${SAMPLE}_R2_trimmed.fastq.gz"
    S="${SEX[$SAMPLE]}"

    if [[ ! -f "${R1}" || ! -f "${R2}" ]]; then
        echo "[WARNING] Missing trimmed reads for ${SAMPLE} — skipping."
        echo "  Expected: ${R1}"
        echo "            ${R2}"
        continue
    fi

    echo "${SAMPLE},${SAMPLE},1,${R1},${R2},${S},0" >> "${OUTPUT_CSV}"
    echo "[OK] Added ${SAMPLE} (${S})"
done

echo ""
echo "Samplesheet written to: ${OUTPUT_CSV}"
cat "${OUTPUT_CSV}"
