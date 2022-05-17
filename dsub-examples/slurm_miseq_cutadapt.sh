#!/bin/bash
#SBATCH -p WORK # partition (queue)
#SBATCH --ntasks=12 # number of tasks to run (used to throttle number of job steps submitted in this script)
#SBATCH --mem-per-cpu=2G # memory allocation per CPU
#SBATCH -t 0-2:00 # time (D-HH:MM)
#SBATCH -o slurm.%N.%j.out # STDOUT
#SBATCH -e slurm.%N.%j.err # STDERR
#SBATCH --job-name=cutadapt

# This is a script to submit cutadapt MiSeq trimming jobs to SLURM

# Date: 30/04/2021


## Define Project ID and input/output paths
PROJECT_ID=xxxxxx # <<<< Modify this
RUN_ID=xxxxxx # <<<< Modify this
READ_PATH=/usr/share/sequencing/miseq/output/${RUN_ID}/Data/Intensities/BaseCalls
OUTPUT_PATH=${HOME}/${PROJECT_ID}/trim_cutadapt
REPORT_PATH=${HOME}/${PROJECT_ID}/reports


# Define trimming parameters
QUALITY=30
MIN_LENGTH=75
N_LIMIT=0
MIN_OVERLAP=5
ADAPTER=CTGTCTCTTATACACATCT


# Make required folders
cd ${HOME}
mkdir -p ${PROJECT_ID}/trim_cutadapt
mkdir -p ${PROJECT_ID}/reports


# Load cutadapt
source /apps/.conda3.sh
conda activate cutadapt


# Run cutadapt v3.3
echo "Starting trimming with cutadapt v3.3"
cd $READ_PATH

for READ1 in ${PROJECT_ID}-*_R1_001.fastq.gz
do
        FILENAME=${READ1%%_L001_R1_001.fastq.gz} #strip suffix
        READ2=$FILENAME"_L001_R2_001.fastq.gz" # add r2 prefix
        OUT1=$FILENAME"_R1_trim.fq.gz"
        OUT2=$FILENAME"_R2_trim.fq.gz"
        REPORT=${REPORT_PATH}/${FILENAME}"_cutadapt.txt"

	#job packing; split resources across multipl jobsteps
        #exclusive flag; start independent proceses within one job submission
	srun --nodes=1 --ntasks=1 --cpus-per-task=1 --exclusive cutadapt \ #called job packing; want to allocate resources defined for multiple jobsteps and split pproessors across them
        -q $QUALITY \
        --minimum-length=$MIN_LENGTH \
        --max-n=$N_LIMIT \
        --overlap=$MIN_OVERLAP \
        -a $ADAPTER \
        -A $ADAPTER \
        -o $OUTPUT_PATH/$OUT1 \
        --paired-output $OUTPUT_PATH/$OUT2 \
        $READ1 $READ2 > $REPORT \
        & # ampersand; run each command synchronously; don't wait for perviou iteration to end
done
wait # Wait until all processes have finished

echo "Trimming with cutadapt done"
