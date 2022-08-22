#!/bin/bash

# ------------------------------------------------------------------------------
# Overview
# Script to to upload data from HPC to GCP sink project (mhra-shr-dev-ssot)
# Purpose: For each sequencing project, create new bucket (format: gs://date-prjid-sequencer), set labels & lifecycle management policies, cp data to bucket
# Input: Type ('M', 'N', or 'N2'), Sequencing Output Folder (eg '200522_M00167_0018_000000000-J3N6L'), Lifecycle Management Policy ('lmp' - optional) and object versioning ('ver' -optional)
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
gcloud auth activate-service-account gsutil@mhra-shr-dev-ssot.iam.gserviceaccount.com --key-file=/usr/share/sequencing/.gcp_sa_keys/gsutil-mhra-shr-dev-ssot.json #need to store this somewhere central

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
# find the list of unique sequencing projects in the run
# ------------------------------------------------------------------------------


if ls $fastqOutput/*.fastq.gz 1> /dev/null 2>&1; then # check for fastq files and silence stderr/stdout

    if [[ $type == M ]]; then
	cutfield='9'
    elif [[ $type == N ]]; then
	cutfield='7'
    else 
	cutfield='10' #confirm for N2
    fi
    projects=$(find $fastqOutput -name "*.fastq.gz" | cut -f$cutfield -d'/' | cut -b1-3 | grep -v [a-z] | sort -u)
else
    echo "emailAndExit "No fastq files found in $fullName""
    exit # leave in until emailandexit working
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


for project in $projects; do 
    echo 
    echo "Creating bucket for sequencing project ${project}..."
    echo
    gsutil ls -b gs://${seqdate}-${project}-${longName} || gsutil mb -b "on" -l "europe-west2" -c "Standard" --pap "enforced" -p 'mhra-shr-dev-ssot' gs://${seqdate}-${project}-${longName}

    echo
    echo "Creating labels for bucket gs://${seqdate}-${project}-${longName}"
    echo
    gsutil label ch -l project-id:mhra-shr-dev-ssot -l creation-date:$datelab -l seq-id:$project -l sequencer:$longName -l seq-date:$seqlab gs://${seqdate}-${project}-${longName}

    # set lifecycle management policy on bucket if 'lmp' parameter given
    if [[ x$3 == xlmp ]]; then
		if [[ -f "../docs/nibsc-bucket-lifecycle-policy.json" ]]; then
        		echo
        		echo "Setting Lifecycle Management Policy on bucket"
        		echo
        		gsutil lifecycle set ../docs/nibsc-bucket-lifecycle-policy.json gs://${seqdate}-${project}-${longName} #set correct path
		else
			echo "Json file not found. Skipping lifecycle management policy..."
		fi
    else
        echo "Skipping lifecycle management policy"
    fi

    # turn on bucket versioning if 'ver' parameter given
    if [[ x$3 == xver || x$4 == xver ]]; then

        echo "Enabling object versioning"
        gsutil versioning set on gs://${seqdate}-${project}-${longName}

    else
        echo "Skipping object versioning"
    fi    


    # turn on logging for the bucket
    echo
    echo "Enabled access logging for gs://${seqdate}-${project}-${longName}"
    echo
    gsutil logging set on -b gs://mhra-shr-dev-seqaccesslog gs://${seqdate}-${project}-${longName}    
    echo "Logging Enabled"

done


# ------------------------------------------------------------------------------
# Copy fastq files to buckets
#
# Parameters
# -c if error occurs on transfer continue copying remaining files 
# -L logfile with detailed info on each item copied
# -m parallel transfer
# ------------------------------------------------------------------------------

for project in $projects; do
    echo
    echo "Copying project $project fastq files to bucket gs://${seqdate}-${project}-${longName}"
    echo
    
    # Sanity check & repeat failed uploads. Create logfile on first iteration through loop and repeat individual uploads for any failures in logfile. Ignores repeats for successful uploads in logfile. Loop continues until exit status 0 returned. see : https://cloud.google.com/storage/docs/gsutil/commands/cp
    until gsutil -m cp -c -L ${seqdate}-${project}-${longName}-gsutil.log $fastqOutput/${project}*.fastq.gz gs://${seqdate}-${project}-${longName}; do
	sleep 10m #rerun cp command after 10 min 
	echo 'Sample(s) upload failed. Retrying...'
    done 

    gsutil cp ${seqdate}-${project}-${longName}-gsutil.log gs://${seqdate}-${project}-${longName}
done

wait 
echo "Data successfully uploaded"

emailAndExit "GCP fastq file uploads completed"
