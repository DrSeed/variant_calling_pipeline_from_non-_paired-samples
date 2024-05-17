#!/bin/bash

# Usage: ./rna_variant_calling_pipeline_multi.sh /path/to/sample_list.txt /path/to/reference.fasta /path/to/known_sites.vcf /output/directory

# Check for the correct number of arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <sample_list.txt> <reference.fasta> <known_sites.vcf> <output_dir>"
    exit 1
fi

# Input parameters
SAMPLE_LIST=$1
REFERENCE_FASTA=$2
KNOWN_SITES_VCF=$3
OUTPUT_DIR=$4

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Create a log file
LOG_FILE="${OUTPUT_DIR}/pipeline.log"

# Function to log and run commands
run_command() {
    COMMAND=$1
    echo "Running: $COMMAND" | tee -a $LOG_FILE
    eval $COMMAND 2>&1 | tee -a $LOG_FILE
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error executing: $COMMAND" | tee -a $LOG_FILE
        exit 1
    fi
}

# Process each sample
while IFS= read -r SAMPLE_BAM; do
    SAMPLE_BASENAME=$(basename $SAMPLE_BAM .bam)
    SAMPLE_OUTPUT_PREFIX="${OUTPUT_DIR}/${SAMPLE_BASENAME}"
    
    # 1. Sort the BAM file
    run_command "samtools sort -o ${SAMPLE_OUTPUT_PREFIX}_sorted.bam ${SAMPLE_BAM}"
    
    # 2. Mark Duplicates with Sambamba
    run_command "sambamba markdup ${SAMPLE_OUTPUT_PREFIX}_sorted.bam ${SAMPLE_OUTPUT_PREFIX}_dedup.bam"
    
    # 3. Index the BAM file
    run_command "sambamba index ${SAMPLE_OUTPUT_PREFIX}_dedup.bam"

    # 4. SplitNCigarReads
    run_command "gatk SplitNCigarReads -R $REFERENCE_FASTA -I ${SAMPLE_OUTPUT_PREFIX}_dedup.bam -O ${SAMPLE_OUTPUT_PREFIX}_split.bam"

    # 5. Base Quality Recalibration (BaseRecalibrator and ApplyBQSR)
    run_command "gatk BaseRecalibrator -R $REFERENCE_FASTA -I ${SAMPLE_OUTPUT_PREFIX}_split.bam --known-sites $KNOWN_SITES_VCF -O ${SAMPLE_OUTPUT_PREFIX}_recal_data.table"
    run_command "gatk ApplyBQSR -R $REFERENCE_FASTA -I ${SAMPLE_OUTPUT_PREFIX}_split.bam --bqsr-recal-file ${SAMPLE_OUTPUT_PREFIX}_recal_data.table -O ${SAMPLE_OUTPUT_PREFIX}_recal.bam"

    # 6. Variant Calling
    run_command "gatk HaplotypeCaller -R $REFERENCE_FASTA -I ${SAMPLE_OUTPUT_PREFIX}_recal.bam -O ${SAMPLE_OUTPUT_PREFIX}.g.vcf -ERC GVCF"

done < "$SAMPLE_LIST"

# Collect all GVCF files for combining
GVCF_FILES=$(ls ${OUTPUT_DIR}/*.g.vcf | sed 's/^/--variant /' | tr '\n' ' ')

# Combine GVCFs
run_command "gatk CombineGVCFs -R $REFERENCE_FASTA $GVCF_FILES -O ${OUTPUT_DIR}/cohort.g.vcf"

# Genotype GVCFs
run_command "gatk GenotypeGVCFs -R $REFERENCE_FASTA -V ${OUTPUT_DIR}/cohort.g.vcf -O ${OUTPUT_DIR}/cohort_raw_variants.vcf"

# Variant Filtering
run_command "gatk VariantFiltration -R $REFERENCE_FASTA -V ${OUTPUT_DIR}/cohort_raw_variants.vcf -O ${OUTPUT_DIR}/cohort_filtered_variants.vcf --filter-expression \"QD < 2.0\" --filter-name \"QD2\" --filter-expression \"FS > 30.0\" --filter-name \"FS30\" --filter-expression \"MQ < 40.0\" --filter-name \"MQ40\" --filter-expression \"SOR > 3.0\" --filter-name \"SOR3\""

echo "Pipeline finished successfully. Filtered VCF: ${OUTPUT_DIR}/cohort_filtered_variants.vcf" | tee -a $LOG_FILE
