# Sarek Pipeline Notes & Observations

**Author:** Meryem Fellah | Sequentia Biotech 2025  
**Sarek version:** 3.5.1 | **Nextflow:** 22.10.6

---

## Why Sarek?

Sarek was included in this benchmark to answer a specific question: **do automated, standardized pipelines produce results comparable to manually configured and individually tuned tool combinations?**

This is practically important because Sarek:
- Encapsulates community best practices validated over years
- Ensures full reproducibility via Docker/Singularity
- Removes parameter uncertainty for inexperienced users
- Is widely used in academic and clinical settings

The trade-off is reduced control — Sarek's internal defaults may differ from a researcher's manual choices.

---

## BWA-MEM Parameter Difference: Sarek vs Manual

A key methodological note from the study. Our manual runs used harmonized parameters across all three aligners:

| Parameter | Manual | Sarek default | Biological impact |
|-----------|--------|---------------|-------------------|
| Seed length `-k` | 21 | 19 | Shorter seed → more seeds found, slightly slower, marginally better in divergent regions |
| Mismatch penalty `-B` | 6 | 4 | Lower penalty in Sarek → more tolerant of mismatches → slightly higher mapping rate but potentially more spurious alignments |
| Gap open `-O` | 5,5 | 6 | Higher Sarek penalty → discourages gap opening → fewer short indels mapped |
| Gap extension `-E` | 3,3 | 1 | Much lower Sarek penalty → once a gap opens, it extends cheaply → may affect indel calling |

**Interpretation:** Sarek's BWA defaults are optimized for a different use case and represent a different point in the sensitivity/specificity space. The differences were kept intentionally to study how pipeline encapsulation affects results.

---

## DeepVariant — Detailed Notes

### Algorithm
1. Candidates are identified from CIGAR strings and pileup data
2. Each candidate is rendered as a **pileup image** (RGB-like matrix):
   - Channel 1: base quality (pixel intensity)
   - Channel 2: mapping quality
   - Channel 3: strand + read position information
3. The CNN (InceptionV3 architecture, fine-tuned on GIAB) classifies each image as:
   - `0/0` — homozygous reference (not a variant)
   - `0/1` — heterozygous variant
   - `1/1` — homozygous alternate variant

### Behavior in our benchmark
- **High recall (~0.99 SNPs):** the CNN is trained to maximize detection, accepting slightly more FP
- **Lower precision (~0.91–0.93):** more permissive than GATK; some false positives pass
- **Position in precision/recall plot:** far left (high recall, lower precision)
- **Most notable on:** samples where SNP density is high; indel recall also strong

### Practical notes
- CPU mode used (no GPU on student server) — significantly slower than GPU mode
- DeepVariant is not directly comparable to manual callers due to model architecture differences
- The model was trained on GIAB data — this could be seen as a minor advantage in a GIAB-based benchmark

---

## Strelka2 — Detailed Notes

### Algorithm
1. **Tier 1:** Fast evaluation using a diploid site model — handles simple SNPs efficiently
2. **Tier 2:** Micro-assembly triggered for complex indels and ambiguous sites
3. **EVS (Empirical Variant Scoring):**
   - A trained scoring model integrating: DP, allele frequency, strand bias, mapping quality, base quality
   - Assigns a confidence score to each variant
   - Calibrated to balance precision and recall

### Behavior in our benchmark
- **Balanced precision/recall:** closer to manual combination cluster
- **Outperforms BCFtools** in both metrics across all samples
- **Slightly behind GATK and FreeBayes** for SNP recall
- **Position in precision/recall plot:** in the main cluster, between GATK and FreeBayes behavior

### Practical notes
- Much faster than DeepVariant (~3× on 30 threads)
- Strelka2 accepts a Manta SV caller output to improve indel detection (not used in this study)
- Well-calibrated for germline calling; somatic mode available but not tested here

---

## Comparison: Sarek vs Manual Runs

| Combination | SNP Precision | SNP Recall | Notes |
|-------------|---------------|------------|-------|
| BWA + GATK (manual) | highest | high | Best precision; conservative |
| BWA + FreeBayes (manual) | ~0.97 | competitive | High detection, slightly more FP |
| BWA + Bcftools (manual) | high | high | Fast, robust for SNPs |
| Minimap2 + GATK (manual) | excellent | high | Competitive with BWA |
| BWA + DeepVariant (Sarek) | ~0.91–0.93 | ~0.99 | Highest recall, lowest precision |
| BWA + Strelka2 (Sarek) | moderate-high | competitive | Best balance within Sarek |

**Key conclusion:** Sarek workflows are reliable and reproducible but do not consistently outperform manually tuned combinations. The automated pipeline's best combination (BWA + Strelka2) represents an acceptable trade-off when automation and reproducibility are priorities.

---

## Execution Environment

- **Server:** Sequentia Biotech student server, Barcelona
- **OS:** Ubuntu 20.04 LTS
- **CPU:** 32 threads
- **RAM:** 128 GB
- **Storage:** `/media/sequentia/sdb1/visitor3/`
- **Containers:** Docker (managed automatically by Sarek)
- **Nextflow cache:** `-resume` flag used to restart from checkpoints

---

## Resuming a Run

Sarek uses Nextflow's work directory for caching. If a run is interrupted:

```bash
# Simply re-run the same command with -resume
nextflow run nf-core/sarek \
    -revision 3.5.1 \
    -profile docker \
    -c config/sarek_deepvariant.config \
    --input samplesheets/samplesheet_giab_all.csv \
    --outdir results/ \
    -resume
```

Nextflow will skip already-completed tasks and resume from the last checkpoint.

---

## Troubleshooting

**Issue: Docker permission error**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Issue: Out of memory during DeepVariant**
- Reduce `max_cpus` in config to free RAM
- Alternatively, run samples one at a time using `samplesheet_HG001.csv`

**Issue: Nextflow not found**
```bash
curl -s https://get.nextflow.io | bash
mv nextflow ~/bin/
```

**Issue: Reference index not found**
```bash
# Rebuild BWA index
bwa index /path/to/reference.fa

# Rebuild samtools index
samtools faidx /path/to/reference.fa
```
