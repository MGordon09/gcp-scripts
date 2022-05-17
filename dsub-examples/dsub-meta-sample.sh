# basic metaphlan dsub script

dsub \
        --provider 'google-cls-v2' \
        --name meta-multi \
	--project ${project_id} \
        --regions europe-west2  \
        --location europe-west2  \
        --network ${project_id}-network  \
        --subnetwork mhra-ngs-dev-eu-west2-2  \
        --service-account nextflow-vm@${project_id}.iam.gserviceaccount.com  \
        --preemptible \
	--retries 1 \
	--logging gs://${project_id}-output/meta-logs  \
	--min-cores 4 \
	--min-ram 16 \
        --image  quay.io/biocontainers/metaphlan:3.0.14--pyhb7b1952_0 \
	--tasks ~/gcsfuse/xxxxx-input/dsub-demo-meta.tsv \
	--script ~/gcsfuse/xxxxx-input/dsub-metaphlan.sh \
	--wait \
	--summary

#parameters
# GLS beta executor. change to 'local' for testing on vm
# name for job
# your project id. captured by $project_id environmental variable
#where compute engine reosurces spun up # do not change!!
# your projects network and subnet
 #the service account used to authenticate to GLS API
#execute on preemptible vms
# logs from the process
 # docker container to run the pipeline - check out biocontainers, dockerhub, gcr
#wait for all jobs to finish
#provide summary on each iteration of the loop
# min ram and min core: automatically selects the smallest machine type available that fits this config
