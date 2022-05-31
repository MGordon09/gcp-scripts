# basic dsub script

dsub  \
        --provider google-cls-v2  \
        --name cutadapt-multi \
	--project ${project_id} \
        --regions europe-west2  \
        --location europe-west2  \
        --network ${project_id}-network  \
        --subnetwork mhra-ngs-dev-eu-west2-2  \
        --service-account nextflow-vm@${project_id}.iam.gserviceaccount.com  \
        --preemptible \
	--retries 3 \
	--logging gs://${project_id}-output/multi-logs  \
        --image  quay.io/biocontainers/cutadapt:4.0--py37h8902056_0 \
        --tasks ~/gcsfuse/xxxxxx-input/dsub-demo.tsv \
	--script ~/gcsfuse/xxxxx-input/dsub-cutadapt.sh \
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
