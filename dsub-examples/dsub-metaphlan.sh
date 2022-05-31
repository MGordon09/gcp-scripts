#!/bin/bash

set -o errexit #exit on error
set -o nounset #treat unset variables as error



#metaphlan parameters
N_PROCESSORS='4'
INPUT_TYPE='fastq'
DB_VERSION='mpa_v30_CHOCOPhlAn_201901'
B2_PATH=`which bowtie2` #path for bt2 executable

# Run cutadapt v3.3
echo "Starting metagenomic profiling with metaphlan3"


echo $B2_PATH


metaphlan \
	${R1},${R2} \
	--index $DB_VERSION \
	--bowtie2db ${META_DB} \
	--bowtie2_exe $B2_PATH \
	--bowtie2out ${BT2_OUT} \
	--nproc $N_PROCESSORS \
	--input_type $INPUT_TYPE \
	-o ${PROFILE}
