# ATAC-seq Shell Pipeline

This repository provides a SLURM-compatible shell script for processing ATAC-seq data in mouse (mm10).

---

## 🧪 Features

- Adapter and quality trimming with `fastp`
- Paired-end alignment with `bowtie2`
- Filtering and sorting with `samtools`
- Duplicate removal with `Picard`
- Coverage track generation with `deepTools` using **CPM normalization**

---

## 🚀 Quick Start

Edit the following variables in `atacseq_pipeline.sh`:

```bash
input_dir="/path/to/fastq"
output_dir="/path/to/output"
bowtie2_index="/path/to/mm10/bowtie2/index/genome"
picard_jar="/path/to/picard.jar"

