#!/bin/bash

# replace this with your own gcp project id
PROJECT_ID=$1

# change this namespace value if you want to use a different namespace
PROVIDER_SECRET_NAMESPACE=crossplane-system

# base64 encode the GCP credentials
BASE64ENCODED_GCP_PROVIDER_CREDS=$(base64 crossplane-gcp-provider-key.json | tr -d "\n")

cat > providerconfig-gcp.yaml <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: gcp-sa-creds-${PROJECT_ID}
  namespace: ${PROVIDER_SECRET_NAMESPACE}
type: Opaque
data:
  credentials: ${BASE64ENCODED_GCP_PROVIDER_CREDS}
---
apiVersion: gcp.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: ${PROVIDER_SECRET_NAMESPACE}
spec:
  # replace this with your own gcp project id
  projectID: ${PROJECT_ID}
  credentials:
    source: Secret
    secretRef:
      name: gcp-sa-creds-${PROJECT_ID}
      namespace: ${PROVIDER_SECRET_NAMESPACE}
      key: credentials
EOF
