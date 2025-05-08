# Sealedsecrets-Auto-Reencrypt

This document outlines a proposed feature to enhance the `kubeseal` command-line interface (CLI) with the capability to automatically re-encrypt all existing `SealedSecret` Kubernetes objects within a cluster. This functionality aims to simplify the process of rotating the Sealed Secrets controller's public key and ensuring that all secrets are encrypted using the latest certificate—regardless of the Kubernetes distribution or environment.

The project introduces a CI/CD pipeline that connects **GitHub**, **Jenkins**, **EKS**, and **ArgoCD**. It automates the following:

- Fetching the latest public certificate from the Sealed Secrets controller
- Re-encrypting all sealed secrets
- Committing changes to GitHub
- Synchronizing updates to the cluster using ArgoCD

This feature will **streamline secret rotation**, strengthen security hygiene, and reduce the operational burden on DevOps teams.

## Goals

- Automate the re-encryption of all SealedSecrets using the latest public certificate
- Integrate the process into a Jenkins CI/CD pipeline
- Store updated secrets in GitHub in a secure path (`sealedsecrets-reencrypted/`)
- Sync changes to the Kubernetes cluster using ArgoCD
- Reduce human error and increase secret rotation reliability

  
## Plan Diagram 
![WhatsApp Image 2025-05-07 at 21 19 44_3360f69c](https://github.com/user-attachments/assets/9f5f549f-e6c4-449e-aa7f-03f1e74b02b2)



## Project Layout
  - infrastructure/argocd/sealedsecrets-app.yaml: File for Argo CD, a tool to automatically deploy and manage your Sealed Secrets in your Kubernetes setup.
  - sealedsecrets-reencrypted/: Folder where the updated, re-encrypted secret files are stored after Jenkins processes them.
  - Jenkinsfile: The script that tells Jenkins exactly how to automatically fetch the new certificate and re-encrypt your secrets.
  - master.key: The secret key the Sealed Secrets system uses to unlock your original secrets.
  - new-cert.pem: The new public key used to lock up your secrets again during the re-encryption process in Jenkins.
  - private-key.pem: Possibly a key used for managing the main secret key (master.key) or other security tasks.
  - public-cert.pem: Similar to private-key.pem, likely involved in managing the security keys.
  - reencrypt.sh: A script you might run manually to help with the re-encryption, similar to what Jenkins does automatically.

    

## Dependencies
  - Kubernetes Cluster: To run the Sealed Secrets controller and deploy the re-encrypted secrets.
  - Sealed Secrets Controller: Installed in the Kubernetes cluster to manage SealedSecret resources.
  - kubeseal CLI: Used in the Jenkins pipeline (and potentially reencrypt.sh) to fetch the certificate and seal/re-encrypt secrets.
  - Argo CD: Managing the deployment of Sealed Secrets configurations.
  - Jenkins: Automation server to run the pipeline.
  - Git: For version control of your configurations and the Jenkinsfile.
  - AWS CLI and Credentials: For interacting with your AWS EKS cluster.

    

## Jenkins Setup
  ### Connect Jenkins with GitHub and Docker (Important: Since the repository is private, authentication is required):
   - Configure GitHub credentials in Jenkins to allow access to the private repository.
   - Set up Docker credentials in Jenkins to push images to Docker Hub.

  ### Create a Pipeline Job:
   - Set up a new Jenkins pipeline to manage the deployment process.

  ### Use the Provided Jenkinsfile:
   - Configure the pipeline using the Jenkinsfile script included in this repository.

     

## Jenkinsfile Pipeline
  This Jenkins pipeline performs the following steps:
  ### Triggers
  Automatically triggered via GitHub webhook push events using `githubPush()`.
  ### Environment Configuration
  - Jenkins credentials store:
      1. AWS Access Key ID & Secret Access Key
      2. GitHub Personal Access Token (PAT)
      3. AWS Region & EKS Cluster name
      4. Optional: ArgoCD authentication token (for manual sync)
   


