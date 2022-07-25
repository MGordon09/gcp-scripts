#!/bin/bash

# ------------------------------------------------------------------------------
# Overview
# Script to to upload data from HPC to GCP sink project (mhra-shr-dev-ssot)
# Purpose: Storage backup - copy entire sequencing project folder from HPC to GCP bucket 
# Intended to act as backup - Coldline Storage class to control expenses. For active use, please use cron-gcpupload.sh
# Input: Type ('M', 'N', or 'N2'), Sequencing Output Folder (eg '200522_M00167_0018_000000000-J3N6L') and Lifecycle Management Policy ('lmp' - optional)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Return Help Page  
# ------------------------------------------------------------------------------

if [ "x$1" == "x" -o "x$2" == "x" ]; then #type and seqencing output folder must be set
  echo "Usage: $0 type seq-output-foldername lifecycle-management-policy ( 'lmp' ) versioning ('ver')" 

  exit
fi

# ------------------------------------------------------------------------------
# Common Variables - needs $type
# ------------------------------------------------------------------------------

type=$1 #M,N,N2,O
fullName=$2 #output folder name
seqdate=`echo $fullName | cut -b1-6`; #date sequenced
seqlab=`echo $seqdate | sed 's/../&-/g;s/-$//'` #add hyphen between every two characters and remove from end of string
datelab=`date +'%d-%m-%y'` #dd-mm-yy for bucket label
echo $type $fullName $seqdate $datelab

# common variables - sequnencer paths etc. $type param used to define paths
source ./common_v2.sh

# ------------------------------------------------------------------------------
# GCP service account authentification for mhra-shr-dev-ssot
# ------------------------------------------------------------------------------

#add gcloud SDK to path
export PATH="$PATH:/opt/google-cloud-sdk/bin"

# set project to mhra-shr-dev-ssot - central sink
gcloud config set project mhra-shr-dev-ssot 

# first authenticate service account using the json key (keep secure)
# TODO move somewhere accessible for other users
gcloud auth activate-service-account gsutil@mhra-shr-dev-ssot.iam.gserviceaccount.com --key-file=/home/AD/mgordon/.config/gcloud/sa-keys/gsutil-mhra-shr-dev-ssot.json #need to store this somewhere central

# ------------------------------------------------------------------------------
# Checks for sequencer output folders for run complete files & Identify projects
# ------------------------------------------------------------------------------

# seach for fastq files; exit if not found
if ls $fastqOutput/*.fastq.gz 1> /dev/null 2>&1; then # test to handle wildcards for fastq files.redirect ls output to make silent
   echo "fastq files found..."
else
   echo "fastq files not found. Exiting..."  
   emailAndExit "No output folder located: $fullName"

fi

# search for run completion file; exit if not found
if [ ! -f $dirOutput/$fullName/$fileCompleted ]; then
    emailAndExit "No $fileCompleted found in output folder"

fi

# ------------------------------------------------------------------------------
# Create buckets, set lifecycle management policies (optional)
#
# Parameters
# -l bucket location: europe-west2
# -c storage class: standard
# -p project: where bucket is created
# --pap public access to buckets restricted
# -b uniform-level access to objects in bucket
# ------------------------------------------------------------------------------


echo "Creating bucket for sequencing run ${fullName}..."
echo
    gsutil ls -b gs://${fullName} || gsutil mb -b "on" -l "europe-west2" -c "Coldline" --pap "enforced" -p 'mhra-shr-dev-ssot' gs://${fullName}

    echo
    echo "Creating labels for bucket gs://${fullName}..."
    echo
    gsutil label ch -l project-id:mhra-shr-dev-ssot -l creation-date:$datelab -l sequencer:$longName -l seq-date:$seqlab gs://${fullName}

    # set lifecycle management policy on bucket if 'lmp' parameter given
    # convert coldline storage to archive after 3 years
    if [[ x$3 == xlmp ]]; then
		if [[ -f "../docs/nibsc-bucket-lifecycle-policy-all.json" ]]; then
        		echo
        		echo "Setting Lifecycle Management Policy on bucket"
        		echo
        		gsutil lifecycle set ../docs/nibsc-bucket-lifecycle-policy-all.json gs://${fullName} #set correct path
		else
			echo "Json file not found. Skipping lifecycle management policy..."
		fi
    else
        echo "Skipping lifecycle management policy"
    fi

    # turn on bucket versioning if 'ver' parameter given
    if [[ x$3 == xver || x$4 == xver ]]; then

        echo "Enabling object versioning"
        gsutil versioning set on gs://${fullName}

    else
        echo "Skipping object versioning"
    fi    


    # turn on logging for the bucket
    echo
    echo "Enabled access logging for gs://${fullName}"
    echo
    gsutil logging set on -b gs://mhra-shr-dev-seqaccesslog gs://${fullName}    
    echo "Logging Enabled"

done


# ------------------------------------------------------------------------------
# Copy fastq files to buckets
#
# Parameters
# -r copy directory and all files
# -c if error occurs on transfer continue copying remaining files 
# -L logfile with detailed info on each item copied
# -m parallel transfer
# ------------------------------------------------------------------------------

for project in $projects; do
    echo
    echo "Copying fastq files to bucket gs://${fullName}"
    echo
    
    # Sanity check & repeat failed uploads. Create logfile on first iteration through loop and repeat individual uploads for any failures in logfile. Ignores repeats for successful uploads in logfile. Loop continues until exit status 0 returned. see : https://cloud.google.com/storage/docs/gsutil/commands/cp
    until gsutil -m cp -r -c -L ${fullName}-gsutil.log ${fullName} gs://${fullName}; do
	sleep 10m #rerun cp command after 10 min 
	echo 'Sample(s) upload failed. Retrying...'
    done 
done

wait 
echo "Data successfully uploaded"

emailAndExit "Sequencing folder upload completed"
