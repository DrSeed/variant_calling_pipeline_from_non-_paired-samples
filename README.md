This method outlines the steps for SNP and indel calling from transcriptome BAM files of non-paired cancer samples. It uses established tools like GATK for pre-processing and variant calling, followed by variant filtering and annotation to derive biological insights from transcriptome BAM of cancer samples.

I will start by sorting the provided BAM files using the Samtools sort to ensure reads are ordered by their genomic coordinates. Prior to that I will ensure that the reference genome hg38 and corresponding annotation files (GTF/GFF) are downloaded and prepared.  Then after that I will use Sambamba markdup to remove deduplicated reads generated during PCR amplification and create index files to enable access to the data. 

**Variant Calling (Pre-processing steps)**
 Split'N'Trim and Reassign Mapping Qualities: Use GATK SplitNCigarReads to split reads into exon segments and hard-clip any sequences overhanging into the intronic regions. 
 
**Base Quality Score Recalibration (BQSR):** Perform base quality score recalibration using known sites of variation (dbSNP, 1000 Genomes) to correct systematic errors made by the sequencing machine. The absence of matched normal samples necessitates additional filtering against population databases to exclude germline variants, ensuring that the focus remains on potential somatic mutations relevant to cancer under study. 

** Variant Calling:** Use GATK HaplotypeCaller in RNA-Seq mode to call variants. This tool identifies SNPs and indels while accounting for splicing events and other complexities in transcriptome data. 
 
Combine GVCFs:  I assume multiple samples are involved in this analysis, so I will perform joint genotyping using GATK GenotypeGVCFs to produce a combined VCF file. 

 Variant Filtering: Apply hard filters or use GATK VariantFiltration to filter out low-confidence variants based on quality metrics such as read depth (DP), variant quality score (QUAL), and mapping quality (MQ).
 
**Post-Processing and Annotation**
**Variant Annotation:** Annotate the filtered variants using tools like ANNOVAR, VEP (Variant Effect Predictor), or SnpEff to predict the functional effects of the variants on genes and transcripts.

Non-paired samples
"non-paired samples" means that each sample is analysed independently without being compared to a matched normal sample. In non-paired analysis, each cancer sample is processed and analysed on its own. There is no direct comparison to a matched normal tissue sample from the same patient. This makes it challenging to distinguish somatic mutations (which occur in cancer cells) from germline mutations (which are inherited and present in every cell). Thus, this methodology must rely on other strategies to filter out likely germline variants, such as comparing against population databases of known variants (e.g., dbSNP, 1000 Genomes, ExAC) to exclude common germline variants. The absence of a normal control makes it harder to confidently call somatic mutations, as some germline variants might still be present in the final variant set. 
Cancer is often driven by somatic mutations that occur in the tumour cells. Identifying these mutations can provide insights into the mechanisms of cancer and potential therapeutic targets. Since the provided RNA-Seq data is from cancer samples without matched normal controls, I presume the primary goal of this study is to identify mutations that have occurred specifically in the tumour cells.# variant_calling_pipeline_from_non-_paired-samples.


# variant_calling_pipeline_from_non-_paired-samples
