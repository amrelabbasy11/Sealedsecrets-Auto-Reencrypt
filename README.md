# Sealedsecrets-Auto-Reencrypt

## Overview
This project automates the process of fetching the latest public key from the Sealed Secrets controller on an AWS EKS cluster and re-sealing all existing SealedSecret Kubernetes objects using the new public key. It integrates GitHub, Jenkins, ArgoCD, and EKS to ensure a secure, fully automated GitOps workflow.

## Project Layout
infrastructure/argocd/sealedsecrets-app.yaml: This suggests you are using Argo CD for GitOps-based deployments. This file likely defines an Argo CD Application resource to manage the deployment of Sealed Secrets or related components in your Kubernetes cluster.

sealedsecrets-reencrypted/: This directory contains the re-encrypted SealedSecret YAML files. Your Jenkins pipeline is generating these.

Jenkinsfile: This is the definition of your Jenkins pipeline, outlining the steps for fetching the new certificate, re-encrypting secrets, and potentially committing the changes.

master.key: This is the master key used by the Sealed Secrets controller to decrypt SealedSecret resources.

new-cert.pem: This file contains the newly fetched public certificate of the Sealed Secrets controller. Your Jenkins pipeline uses this to re-encrypt the secrets.

private-key.pem: This might be related to generating or managing the master key or other aspects of the Sealed Secrets setup.

public-cert.pem: Similar to private-key.pem, this could be part of the key management lifecycle.

reencrypt.sh: This looks like a shell script that might contain logic for manually triggering or assisting with the re-encryption process. Your Jenkinsfile likely orchestrates similar steps.
