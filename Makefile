# John C. Wright
# johnwright@eecs.berkeley.edu
# Xuan G. Luong
# xluong@berkeley.edu
#
# RNA Sequencing Makefile

default: idxstats

# Base directory
base_dir = /Volumes/HayesLabHardDrive

# Source directory
fq_dir = $(base_dir)/THXL

# Trimmed FQ directory
fqt_dir = $(base_dir)/THXL_trim

# Fasta directory
fa_dir = $(base_dir)/fasta

# Concatenated fasta directory
fac_dir = $(base_dir)/fasta_cat

# Index directory
idx_dir = $(base_dir)/indexes
idx_base = XL_genome
idx_suffixes = .1.bt2 .2.bt2 .3.bt2 .4.bt2 .rev.1.bt2 .rev.2.bt2
idx_src = $(base_dir)/Xla.v91.repeatMasked.fa
faidx = $(idx_src).fai

# SAM directory
sam_dir = $(base_dir)/sam

# BAM directory
bam_dir = $(base_dir)/bam

# Index stats directory
idxstats_dir = $(base_dir)/idxstats

# Source fastq files
fq_files = $(wildcard $(fq_dir)/*.fastq.gz)
basenames_ext = $(foreach x,$(fq_files),$(basename $(basename $(notdir $(x)))))
basenames = $(shell echo $(basenames_ext) | xargs -n1 echo | sed -e "s/_[0-9]\\{1,3\\}$$//g" | sort -u)
fqtgz_files = $(foreach x,$(basenames_ext),$(fqt_dir)/$(x)_trim.fastq.gz)
fqt_files = $(foreach x,$(basenames_ext),$(fqt_dir)/$(x)_trim.fastq)
fa_files = $(foreach x,$(basenames_ext),$(fa_dir)/$(x).fasta)
fac_files = $(foreach x,$(basenames),$(fa_dir)/$(x).fasta)
sam_files = $(foreach x,$(basenames),$(sam_dir)/$(x).sam)
uniq_sam_files = $(foreach x,$(basenames),$(sam_dir)/$(x).unique.sam)
bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).bam)
sort_bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).sorted.bam)
uniq_bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).unique.bam)
uniq_sort_bam_files = $(foreach x,$(basenames),$(bam_dir)/$(x).unique.sorted.bam)
idxstats_files = $(foreach x,$(basenames),$(idxstats_dir)/$(x).txt)
uniq_idxstats_files = $(foreach x,$(basenames),$(idxstats_dir)/$(x).unique.txt)
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

# Step 2c: concatenate fasta files together
$(fac_dir)/%.fasta: $(fa_dir)/%_*.fasta
	mkdir -p $(fac_dir)
	cat $^ > $@

# Step 3a: build index
$(idx_files): $(idx_src)
	mkdir -p $(idx_dir)
	$(bt2b) $< $(idx_dir)/$(idx_base)

# Step 3b: build the faidx file for use with samtools
$(faidx): $(idx_src)
	$(samtools) faidx $(idx_src)

# Step 4a: map reads
$(sam_dir)/%.sam: $(fac_dir)/%.fasta $(idx_files)
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
$(idxstats_dir)/%.txt: $(bam_dir)/%.sorted.bam
	mkdir -p $(idxstats_dir)
	$(samtools) idxstats $< > $@

# Step 4a2: generate unique sam files
$(sam_dir)/%.unique.sam: $(sam_dir)/%.sam
	grep AS: $< | grep -v XS: > $@

.PHONY: fqtrim
fqtrim: $(fqt_files)

.PHONY: fa
fa: $(fac_files)

.PHONY: index
index: $(idx_files)

.PHONY: sam
sam: $(sam_files) $(uniq_sam_files)

.PHONY: bam
bam: $(sort_bam_files) $(uniq_sort_bam_files)

.PHONY: idxstats
idxstats: $(idxstats_files) $(uniq_idxstats_files)

.PHONY: clean
clean:
	rm -rf $(fqt_files) $(fqtgz_files) $(fa_files) $(fac_files) $(idx_files) $(faidx) $(sam_files) $(bam_files) $(sort_bam_files) \
	$(uniq_sam_files) $(uniq_bam_files) $(uniq_sort_bam_files) $(idxstats_files) $(uniq_idxstats_files)
