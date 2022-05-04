#!/bin/bash

# ------------------------------------------------------------------------------
# Overview
# script run on hpc-admin
# This updated script (V2) sets env variables (output dir, mount locations etc) depending on machine type set (M,N, N2 or O).
# Email&Exit function defined
# Credit to Mark Preston & Tom Bleazard for original script 
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Email and Exit Function
# Input parameters: type and email body
# ------------------------------------------------------------------------------

function emailAndExit () {

  subject="Subject: $type $longName"

  if [ ! -z "$1" ]; then
    body=$1  
  else
    body="No body"
  fi

  echo -e "To:$recipients\n$subject\n\n$body" 

  echo -e "To:$recipients\n$subject\n\n$body" | /usr/sbin/sendmail -F HPC-admin -t $recipients #send mail sends preformatted emails. takes in stdin and sends from HPC (-F) to recipients (-t)

  exit 
}

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------

#these env variables are sourced in other scripts

case "$type" in #type var must be one of M,N,N2,O

# MiSeq
  "M")
    recipients="Martin.Gordon@nibsc.org"
    longName="miseq"
    mntSeq="/sequencer/miseq" #where seq is mounted?
    dirSeq="$mntSeq/MiSeqOutput/"   ### trailing /
    mntLocal="/sequencing"
    dirLocal="$mntLocal/miseq" # where seq output is stored on HPC
    dirOutput="$dirLocal/output"
    fastqOutput=$dirOutput/${seqdate}_*/Data/Intensities/BaseCalls #raw fastq location - try seqdate, if not seqDir
    fileCompleted="CompletedJobInfo.xml"
  ;;
# NextSeq
  "N")
    recipients="Martin.Gordon@nibsc.org"
    longName="nextseq500"
    mntSeq="/sequencer/nextseq" #where seq is mounted?
    dirSeq="$mntSeq/Output/"   ### trailing /
    mntLocal="/sequencing"
    dirLocal="$mntLocal/nextseq"  # where seq output is stored on HPC
    dirOutput="$dirLocal/output"
    fastqOutput="$dirLocal/processed/$seqdate/fastq" #raw fastq location
    fileCompleted="RunCompletionStatus.xml"
  ;;
  # NextSeq 2000; where are the fastq files
  "N2")
    recipients="Martin.Gordon@nibsc.org"
    longName="nextseq2000"
    #mntSeq="$mntLocal/nextseq2000" # not sure if this is where it is mounted??
    #dirSeq="$mntSeq/"   needs to be defined  ### trailing /
    mntLocal="/sequencing"
    dirLocal="$mntLocal/nextseq2000"
    dirOutput="$dirLocal/output" #or data tbd..
    fastqOutput="$dirOutput/$seqDir" #need to set
    fileCompleted="CopyComplete.txt" #3 options decided on copycomplete; created by UCS service when allfiles copied to final destinations. See post: https://www.biostars.org/p/400346/
  ;;
# NMR
  "O")
    recipients="Tim.Rudd@nibsc.org"
    mntLocal="/backup"
    longName="NMR"
    mntSeq="/equipment/nmr"
    dirSeq="$mntSeq/"   ### trailing /
    mntLocal="/backup"
    dirLocal="$mntLocal/nmr"
    dirOutput="$dirLocal"
    fileCompleted=""
  ;;
# Error - standard response if nothing or any string except above entered
  "" | *)
    emailAndExit "badType:$type" #email body when error
  ;;
esac #required to end a case statement

# TODO: create folder for log files on hpc
dirProcessed="$dirLocal/processed/$shortName" #this is the date folder
dirProject="$mntLocal/projects" # /sequencing/projects
