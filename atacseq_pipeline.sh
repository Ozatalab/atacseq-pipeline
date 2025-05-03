#!/bin/bash -l

#SBATCH -A naiss2024-22-1454
#SBATCH -J atacseq_pipeline
#SBATCH -p main
#SBATCH -t 24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -e slurm-%j.err
#SBATCH -o slurm-%j.out
#SBATCH --mail-type=ALL

set -euo pipefail

# ---------------- USER CONFIGURATION ----------------

input_dir="/path/to/fastq"                          # Folder with *_R1_001.fastq.gz and *_R2_001.fastq.gz
output_dir="/path/to/output"
bowtie2_index="/path/to/mm10/bowtie2/index/genome"
picard_jar="/path/to/picard.jar"

# ---------------- SETUP ----------------

mkdir -p "$output_dir"/{trimmed,aligned,log}

# ---------------- MAIN LOOP ----------------

for file_r1 in "$input_dir"/*_R1_001.fastq.gz; do
  file_r2="${file_r1/_R1_001.fastq.gz/_R2_001.fastq.gz}"
  sample_name=$(basename "$file_r1" _R1_001.fastq.gz)

  echo "🔹 Processing $sample_name"

  trimmed_r1="$output_dir/trimmed/${sample_name}_R1_trimmed.fastq.gz"
  trimmed_r2="$output_dir/trimmed/${sample_name}_R2_trimmed.fastq.gz"
  log_file="$output_dir/log/${sample_name}.log"
  align_dir="$output_dir/aligned/${sample_name}"
  mkdir -p "$align_dir"

  # Step 1: fastp trimming
  fastp \
    -i "$file_r1" -I "$file_r2" \
    -o "$trimmed_r1" -O "$trimmed_r2" \
    --html "$align_dir/${sample_name}_fastp.html" > "$log_file" 2>&1

  # Step 2: bowtie2 alignment
  bowtie2 -p 16 -x "$bowtie2_index" \
    -1 "$trimmed_r1" -2 "$trimmed_r2" \
    --very-sensitive --no-unal --no-mixed --no-discordant \
    -S "$align_dir/${sample_name}.sam" >> "$log_file" 2>&1

  # Step 3: process BAM files
  samtools view -F 4 -b "$align_dir/${sample_name}.sam" > "$align_dir/${sample_name}.bam"
  samtools sort "$align_dir/${sample_name}.bam" -o "$align_dir/${sample_name}_sorted.bam"
  samtools index "$align_dir/${sample_name}_sorted.bam"
  samtools view -b -q 20 -o "$align_dir/${sample_name}_uniquely_mapped.bam" "$align_dir/${sample_name}_sorted.bam"
  samtools index "$align_dir/${sample_name}_uniquely_mapped.bam"
  samtools flagstat "$align_dir/${sample_name}_uniquely_mapped.bam" > "$align_dir/${sample_name}.stat"

  # Step 4: remove duplicates
  java -jar "$picard_jar" MarkDuplicates \
    -I "$align_dir/${sample_name}_uniquely_mapped.bam" \
    -O "$align_dir/${sample_name}_mdu.bam" \
    -M "$align_dir/${sample_name}_metrics.txt" \
    --REMOVE_DUPLICATES true
  samtools index "$align_dir/${sample_name}_mdu.bam"

  # Step 5: Generate BigWig (CPM normalization)
  bamCoverage \
    -b "$align_dir/${sample_name}_mdu.bam" \
    -o "$align_dir/${sample_name}.bw" \
    --normalizeUsing CPM

  echo "✅ $sample_name complete"
done

echo "🎉 All samples processed."
