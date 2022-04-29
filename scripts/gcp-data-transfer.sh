#!/bin/bash

# ------------------------------------------------------------------------------
# Script to to upload data from HPC to GCP bucket
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Return Help Message on Error
# ------------------------------------------------------------------------------

if [ ! $# -eq 3 ]; then # if 4 CL arguments not passed then return err msg
#if [ "x$1" == "x" -o "x$2" == "x" -o "x$3" == "x" ]; then
  echo "Usage: $0 filepath gcp-project-id bucketname"

  exit
fi

# ------------------------------------------------------------------------------
# Define Variables
# ------------------------------------------------------------------------------

path="$PATH":/opt/google-cloud-sdk/bin/ #add gcloud tools to path

filepath=$1 #path to files
gcpproject=$2 #gcp project id
bucketname=$3 #name of bucket to move data to (or create if absent)

# ------------------------------------------------------------------------------
# Set Project
# ------------------------------------------------------------------------------

# set gcp project
gcloud config set project $gcpproject

# ------------------------------------------------------------------------------
# Create bucket; First Check If Exists
# ------------------------------------------------------------------------------

# Parameters:
# -l location: europe-west2
# -c storage class
# -p project where bucket is created
# --pap public access to buckets restricted
# -b uniform-level access to objects in bucket 

echo "Checking bucket..."
gsutil ls -b gs://$bucketname || gsutil mb -b "on" -l "europe-west2" -c "Standard" --pap "enforced" -p $gcpproject gs://$bucketname


# ------------------------------------------------------------------------------
# Set bucket lifecycle management policy
# ------------------------------------------------------------------------------

# TBD


# ------------------------------------------------------------------------------
# Copy data to bucket
# ------------------------------------------------------------------------------

# Parameters:
# -r recursive
# -I list of files to copy (can include globbing(
# -m parallel transfer

# maybe loop and check exit status per transfer instead... can use wildcards in names then rather than relying on file with paths

	if [[ -f $filepath ]] && [[ $filepath == *.txt ]]; then
	echo "Source is a text file!"
	cat $filepath | gsutil -m cp -I gs://${bucketname}

        elif [[ -f $filepath ]]; then
        echo "Source is a single file!"
        gsutil cp $filepath gs://${bucketname}

	elif [[ -d $filepath ]]; then
	echo "Source is a directory!"
	gsutil -m cp -r $filepath gs://${bucketname}

	else
	echo "Path does not exist... exiting"
	exit 1
fi


echo "Done copying files!"

# maybe implement some kind of error checking.. possibly loop for this

#if [ $? -ne 0 ]
         #then
         #       echo "error for sample..retry upload"
         #       cat $filepath |  echo gsutil cp -I gs://${bucketname}
         #fi
