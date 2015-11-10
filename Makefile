# John C. Wright
# johnwright@eecs.berkeley.edu
# Xuan G. Luong
# xluong@berkeley.edu
#
# RNA Sequencing Makefile

default: fa

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

# Source fastq files
fq_files = $(wildcard $(fq_dir)/*.fastq.gz)
basenames = $(foreach x,$(fq_files),$(basename $(basename $(notdir $(x)))))
fqtgz_files = $(foreach x,$(basenames),$(fqt_dir)/$(x)_trim.fastq.gz)
fqt_files = $(foreach x,$(basenames),$(fqt_dir)/$(x)_trim.fastq)
fa_files = $(foreach x,$(basenames),$(fa_dir)/$(x).fasta)
idx_files = $(addprefix $(idx_dir)/$(idx_base),$(idx_suffixes))

# Trimmomatic
trim_dir = $(abspath ./Trimmomatic-0.33)
trim_jar = $(trim_dir)/trimmomatic-0.33.jar
trim_adapter = TruSeq3-SE
trim_opts = ILLUMINACLIP:$(trim_dir)/adapters/$(trim_adapter).fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

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
	bowtie2-build $< $(idx_dir)/$(idx_base)

# Step 3b: map reads


.PHONY: fqtrim
fqtrim: $(fqt_files)

.PHONY: fa
fa: $(fa_files)

.PHONY: index
index: $(idx_files)

.PHONY: clean
clean:
	rm -rf $(fqt_files) $(fqtgz_files) $(fa_files) $(idx_files)
