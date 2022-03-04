# crossplane-demo

This is a project for playing with Crossplane on Google Cloud Platform (GCP). 
We have to set up some authorities within a GCP project. Suppose that there 
exists a GCP project with ID `crossplane-demo-123456`, this will be used in 
the rest of this demonstration.

## Preliminaries

First of all, we create a service account in the GCP project and grant it 
several authorities to a set of GCP services, such as GCE, GCS, etc. We 
compiled the entire process into a shell script as follows.

```shell

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
gcloud --project $GCP_PROJECT_ID iam service-accounts keys create --iam-account $CROSSPLANE_SA crossplane-gcp-provider-key.json

# assign roles needed by Crossplane
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/cloudsql.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/container.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/redis.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/compute.networkAdmin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member "serviceAccount:$CROSSPLANE_SA" --role="roles/storage.admin"
```

The above shell script could be found in `sbin/crossplane-init-gcp.sh` of this 
repository. Note that the service account is named `crossplane-sa`. We may 
execute the above script as follows with the aforementioned GCP project ID.

```shell
$ git clone https://github.com/tsungchih/crossplane-demo.git
$ cd crossplane-demo
$ sbin/crossplane-init-gcp.sh crossplane-demo-123456
```

After having executed the above commands, we will acquire a JSON file, 
`crossplane-gcp-provider-key.json`, containing authentication information 
with respect to the service account. We will use it to generate a `Secret` 
for a provider.

## Installation of Crossplane Providers

We will not go through the detail of installing Crossplane since it is simple. 
We may follow installation steps described in the [Crossplane web site](https://crossplane.io/docs/v1.6/getting-started/install-configure.html). 
Assume that an instance of Crossplane had been installed in a GKE cluster, we 
will then have to install a provider. The list of available providers could be 
found [here](https://crossplane.io/docs/v1.6/concepts/providers.html). The provider 
we are going to install is the [provider-gcp](https://github.com/crossplane/provider-gcp). 
The provider will be manually installed by means of the following manifest.

```yaml
# providers/provider-jet-gcp.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-jet-gcp
  namespace: crossplane-system
spec:
  package: "crossplane/provider-jet-gcp:v0.2.0"
```

We can then apply the above manifest to install the provider as follows.

```shell
$ kubectl apply -f providers/provider-jet-gcp.yaml
$ kubectl get provider.pkg
NAME               INSTALLED   HEALTHY   PACKAGE                              AGE
provider-jet-gcp   True        True      crossplane/provider-jet-gcp:v0.2.0   12s
```

## Configuration of Installed Providers

After the `HEALTHY` of the installed provider has become `True`, We have to 
create a corresponding `ProviderConfig` resource for the `Provider` to use 
for authentication when reconciling infrastructure resources on Cloud. Herein, 
we want the provider to use the service account created in the section of 
Preliminaries for reconciling infrastructure resources within GCP project 
`crossplane-demo-123456`.

We have to generate a `Secret` first and apply it to the GKE cluster.

```shell
$ kubectl create secret generic gcp-sa-creds -n crossplane-system --from-file=credentials=crossplane-gcp-provider-key.json --dry-run=client -o yaml > secret-gcp.yaml
$ kubectl apply -f secret-gcp.yaml
```

Then we create a `ProviderConfig` as follows.

```yaml
# conf/providerconfig-jet-gcp.yaml
---
apiVersion: gcp.jet.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: provider-jet-gcp
  namespace: crossplane-system
spec:
  projectID: crossplane-demo-123456
  credentials:
    source: Secret
    secretRef:
      name: gcp-sa-creds
      namespace: crossplane-system
      key: credentials

```

We apply the above `ProviderConfig` to the GKE cluster.

```shell
$ kubectl apply -f conf/providerconfig-jet-gcp.yaml
```

## Test

We may now create a bucket on GCP as an example. The corresponding manifest 
is shown as follows.

```yaml
# gcp/projects/crossplane-demo-123456/gcs-bucket-example.yaml
apiVersion: storage.gcp.jet.crossplane.io/v1alpha2
kind: Bucket
metadata:
  name: bucket-example
  annotations:
    crossplane.io/external-name: crossplane-example-bucket-asdfghjkl
    terrajet.crossplane.io/provider-meta: '{"e2bfb730-ecaa-11e6-8f88-34363bc7c4c0":{"create":60000000000,"read":60000000000}}'
spec:
  providerConfigRef:
    name: provider-jet-gcp
  forProvider:
    project: playground-341511
    location: ASIA
    storageClass: MULTI_REGIONAL
    labels:
      managedby: crossplane
```

Note that the bucket on GCP will be deleted right after we have deleted the 
`Bucket` resource.
