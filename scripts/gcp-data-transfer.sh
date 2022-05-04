#!/bin/bash

# ------------------------------------------------------------------------------
# Script to to upload data from HPC to GCP bucket
# ------------------------------------------------------------------------------

echo "Please run 'gcloud init --no-browser' to authenticate using your GCP user account before running script"


# ------------------------------------------------------------------------------
# Return Help Message on Error
# ------------------------------------------------------------------------------

if [ "x$1" == "x" -o "x$2" == "x" -o "x$3" == "x" -o "x$4" == "x" ]; then #first 4 params must be set
  echo "Usage: $0 sourcetype ('d', 'f', 't') filepath gcp-project-id bucketname (no 'gs:// prefix) lmp(lifecycle management on -optional)"
  echo "Example: $0 'd' '/path/to/directory' 'mhra-ngs-dev-xxxx' 'example-bucket'"
  exit
fi


# ------------------------------------------------------------------------------
# Define Variables
# ------------------------------------------------------------------------------


datelab=$(date +'%d-%m-%y') #dd-mm-yy
export PATH="$PATH:/opt/google-cloud-sdk/bin" #add gcloud sdk to path

source=$1
filepath=$2 #path to files
gcpproject=$3 #gcp project id
bucketname=$4 #name of bucket to move data to (or create if absent)
lifecycle=$5 # enable labelling & lifecycle managemeent policy 

# ------------------------------------------------------------------------------
# Set Project
# ------------------------------------------------------------------------------

# check for project
gcloud projects list --filter $gcpproject

# set gcp project
gcloud config set project $gcpproject || exit

# ------------------------------------------------------------------------------
# Create bucket & labels; First Check If Exists
# ------------------------------------------------------------------------------

# Parameters:
# -l location: europe-west2
# -c storage class
# -p project where bucket is created
# --pap public access to buckets restricted
# -b uniform-level access to objects in bucket 

echo "Checking bucket..."
gsutil ls -b gs://$bucketname || gsutil mb -b "on" -l "europe-west2" -c "Standard" --pap "enforced" -p $gcpproject gs://$bucketname

# Adding labels
gsutil label ch -l project-id:$gcpproject -l creation-date:$datelab gs://$bucketname

# ------------------------------------------------------------------------------
# Set Bucket Lifecycle Management Policy & Labelling: Optional
# LMP: live storage 3 months -> coldline storage -> 3 years -> archive 12 years
# ------------------------------------------------------------------------------

if [[ x$5 == xlmp ]]; then
	if [[ -f "../docs/nibsc-bucket-lifecycle-policy.json" ]]; then #lifecycle policy implemented if 'lmp' flag given
        	echo
                echo "Setting Lifecycle Management Policy on bucket"
                echo
                gsutil lifecycle set ../docs/nibsc-bucket-lifecycle-policy.json gs://$bucketname
        else
                echo "Json file not found. Skipping lifecycle management policy..."
        fi
else
        echo "Skipping lifecycle management policy"
fi


# ------------------------------------------------------------------------------
# Copy data to bucket
# ------------------------------------------------------------------------------

# Parameters:
# -r recursive
# -I list of files to copy (can include globbing(
# -m parallel transfer

# maybe loop and check exit status per transfer instead... can use wildcards in names then rather than relying on file with paths

#	if [[ -f $filepath ]] && [[ $filepath == *.txt ]]; then#
#	echo "Source is a text file!"
#	cat $filepath | gsutil -m cp -I gs://${bucketname}

#        elif [[ -f $filepath ]]; then
#        echo "Source is a single file!"
#        gsutil cp $filepath gs://${bucketname}

#	elif [[ -d $filepath ]]; then
#	echo "Source is a directory!"
#	gsutil -m cp -r $filepath gs://${bucketname}

#	else
#	echo "Path does not exist... exiting"
#	exit 1
#fi

case "$source" in

        # source is directory
        "d")
        if [[ -d $filepath ]]; then
        echo 'Source is a directory!'
        until gsutil -m cp -r -c -L ${bucketname}-gsutil.log $filepath gs://${bucketname}; do
                sleep 10
                echo 'Sample(s) upload failed. Retrying...'
        done
	fi
	;;

        "f")
        if ls $filepath 1> /dev/null 2>&1; then
        echo 'Source is file(s)!'
        until gsutil -m cp -c -L ${bucketname}-gsutil.log $filepath gs://${bucketname}; do
                sleep 10
                echo 'Sample(s) upload failed. Retrying...'
	done
	fi
	;;


        # source is text file with file paths
        "t")
        if [[ -f $filepath ]]; then
        echo 'Source is text file!'
        until gsutil -m cp -c -I -L ${bucketname}-gsutil.log gs://${bucketname}; do sleep 10; done < <(cat $filepath)
	fi
	;;
	
	# if anyother characters used exit
	" " | *)
	echo 'Source param not recognised (must be 'd', 'f' or 't'). Exiting...'
	exit
	;;
esac

echo 'Done copying files!'


