#!/bin/bash

# the target project id on GCP
GCP_PROJECT_ID=$1

# the service account email
CROSSPLANE_SA="crossplane-sa@$GCP_PROJECT_ID.iam.gserviceaccount.com"

# enable Kubernetes API
gcloud --project $GCP_PROJECT_ID services enable container.googleapis.com

# enable CloudSQL API
gcloud --project $GCP_PROJECT_ID services enable sqladmin.googleapis.com

# enable Redis API
gcloud --project $GCP_PROJECT_ID services enable redis.googleapis.com

# enable Compute API
gcloud --project $GCP_PROJECT_ID services enable compute.googleapis.com

# enable Service Networking API
gcloud --project $GCP_PROJECT_ID services enable servicenetworking.googleapis.com

# enable Additional APIs needed for the example or project
# See `gcloud services list` for a complete list

# create service account
gcloud --project $GCP_PROJECT_ID iam service-accounts create crossplane-sa --display-name "Crossplane Service Account"

# create service account key (this will create a `crossplane-gcp-provider-key.json` file in your current working directory)
gcloud --project $GCP_PROJECT_ID iam service-accounts keys create --iam-account $CROSSPLANE_SA keys/crossplane-gcp-provider-key.json

# assign roles needed by Crossplane
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/cloudsql.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/container.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/redis.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/compute.networkAdmin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/storage.admin"
