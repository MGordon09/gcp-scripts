# basic dsub script

dsub  \
        --provider google-cls-v2  \ # GLS beta executor. change to 'local' for testing on vm
        --name dsub-${project_id}-cutadapt \ # name for job
	--project ${project_id} \ # your project id. captured by $project_id environmental variable
        --regions europe-west2  \ #where compute engine reosurces spun up # do not change!!
        --location europe-west2  \  # where job executions are deployed to GLS API. GLS API only stores pipeline execution metadata in certain regions #Do not change!! 
        --network ${project_id}-network  \ # your projects network and subnet
        --subnetwork mhra-ngs-dev-eu-west2-2  \
        --service-account nextflow-vm@${project_id}.iam.gserviceaccount.com  \ #the service account used to authenticate to GLS API
        --preemptible \ #execute on preemptible vms
	--logging gs://${project_id}-output/logs  \ # logs from the process
        --input RAW=gs://${project_id}-input/ERR3451456_short_R1.fastq.gz  \
        --output TRIM=gs://${project_id}-output/ERR3451456_short_trimmed_R1.fastq.gz  \
        --image  'quay.io/biocontainers/cutadapt' \ # docker container to run the pipeline - check out biocontainers registry (quay.io/biocontainers)
        --command 'cutadapt -q30 -o $TRIM $RAW'  \
	--wait \ #wait for all jobs to finish
	--summary #provide summary on each iteration of the loop
