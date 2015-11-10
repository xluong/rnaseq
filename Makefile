# John C. Wright
# johnwright@eecs.berkeley.edu
# Xuan G. Luong
# xluong@berkeley.edu
#
# RNA Sequencing Makefile

default: bam

# Base directory
base_dir = /Volumes/HayesLabHardDrive

# Source directory
fq_dir = $(base_dir)/THXL

# Trimmed FQ directory
fqt_dir = $(base_dir)/THXL_trim

# Fasta directory
fa_dir = $(base_dir)/fasta

# Index directory
idx_dir = $(base_dir)/indexes
idx_base = XL_genome
idx_suffixes = .1.bt2 .2.bt2 .3.bt2 .4.bt2 .rev.1.bt2 .rev.2.bt2
idx_src = $(abspath ./src)/Xla_L6RMV10_cds.fa
faidx = $(idx_src).fai

# SAM directory
sam_dir = $(base_dir)/sam

# BAM directory
bam_dir = $(base_dir)/bam

# Source fastq files
fq_files = $(wildcard $(fq_dir)/*.fastq.gz)
basenames = $(foreach x,$(fq_files),$(basename $(basename $(notdir $(x)))))
fqtgz_files = $(foreach x,$(basenames),$(fqt_dir)/$(x)_trim.fastq.gz)
fqt_files = $(foreach x,$(basenames),$(fqt_dir)/$(x)_trim.fastq)
fa_files = $(foreach x,$(basenames),$(fa_dir)/$(x).fasta)
sam_files = $(foreach x,$(basenames),$(sam_dir)/$(x).sam)
bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).bam)
sort_bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).sorted.bam)
idx_files = $(addprefix $(idx_dir)/$(idx_base),$(idx_suffixes))

# Trimmomatic
trim_dir = $(abspath ./Trimmomatic-0.33)
trim_jar = $(trim_dir)/trimmomatic-0.33.jar
trim_adapter = TruSeq3-SE
trim_opts = ILLUMINACLIP:$(trim_dir)/adapters/$(trim_adapter).fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

# Bowtie2
bt2 = bowtie2
bt2b = bowtie2-build

# Samtools
samtools = samtools

# fastq to fasta converter
fq2fa = fastq_to_fasta
fq2fa_args = -Q33 -i

# Step 1: trim the fastq files
.SECONDARY: $(fqtgz_files)
$(fqt_dir)/%_trim.fastq.gz: $(fq_dir)/%.fastq.gz
	mkdir -p $(fqt_dir)
	java -jar $(trim_jar) SE -phred33 $< $@ $(trim_opts)

# Step 2a: gunzip fastq.gz
$(fqt_dir)/%.fastq: $(fqt_dir)/%.fastq.gz
	gunzip $<

# Step 2b: convert fastq to fasta
$(fa_dir)/%.fasta: $(fqt_dir)/%_trim.fastq
	mkdir -p $(fa_dir)
	$(fq2fa) $(fq2fa_args) $< -o $@

# Step 3a: build index
$(idx_files): $(idx_src)
	mkdir -p $(idx_dir)
	$(bt2b) $< $(idx_dir)/$(idx_base)

# Step 3b: build the faidx file for use with samtools
$(faidx): $(idx_src)
	$(samtools) faidx $(idx_src)

# Step 4a: map reads
$(sam_dir)/%.sam: $(fa_dir)/%.fasta $(idx_files)
	mkdir -p $(sam_dir)
	$(bt2) -x $(idx_dir)/$(idx_base) -f -U $< -S $@

# Step 4b: convert sam files to bam files
$(bam_dir)/%.bam: $(sam_dir)/%.sam $(faidx)
	mkdir -p $(bam_dir)
	$(samtools) view -bt $(faidx) -o $@ $<

# Step 4c: sort the bam files
$(bam_dir)/%.sorted.bam: $(bam_dir)/%.bam
	$(samtools) sort $< $(bam_dir)/$*.sorted
	$(samtools) index $(bam_dir)/$*.sorted.bam

# Step 4d: generate stats about the sorted bam files
#	TODO
#	$(samtools) idxstats $(bam_dir)/$*.sorted.bam

.PHONY: fqtrim
fqtrim: $(fqt_files)

.PHONY: fa
fa: $(fa_files)

.PHONY: index
index: $(idx_files)

.PHONY: sam
sam: $(sam_files)

.PHONY: bam
bam: $(sort_bam_files)

.PHONY: clean
clean:
	rm -rf $(fqt_files) $(fqtgz_files) $(fa_files) $(idx_files) $(faidx) $(sam_files) $(bam_files) $(sort_bam_files)
