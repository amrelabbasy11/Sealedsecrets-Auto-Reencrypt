# Sealedsecrets-Auto-Reencrypt

##  Overview

This document outlines a proposed feature to enhance the `kubeseal` CLI tool by **automating the re-encryption of all `SealedSecret` resources in a Kubernetes cluster**. This allows seamless rotation of the Sealed Secrets controller's public key without manual secret management.

The project is built using a **CI/CD pipeline** consisting of:

- **GitHub**: Stores the SealedSecrets
- **Jenkins**: Automates re-encryption, commits, and push
- **ArgoCD**: Syncs changes to the Kubernetes cluster
- **EKS (AWS)**: The target Kubernetes environment

---

## Goals

- Automate the re-encryption of all SealedSecrets using the latest public certificate
- Integrate the process into a Jenkins CI/CD pipeline
- Store updated secrets in GitHub in a secure path (`sealedsecrets-reencrypted/`)
- Sync changes to the Kubernetes cluster using ArgoCD
- Reduce human error and increase secret rotation reliability

  
## Plan Diagram 
![WhatsApp Image 2025-05-07 at 21 19 44_3360f69c](https://github.com/user-attachments/assets/9f5f549f-e6c4-449e-aa7f-03f1e74b02b2)

---

## Project Layout
  - infrastructure/argocd/sealedsecrets-app.yaml: File for Argo CD, a tool to automatically deploy and manage your Sealed Secrets in your Kubernetes setup.
  - sealedsecrets-reencrypted/: Folder where the updated, re-encrypted secret files are stored after Jenkins processes them.
  - Jenkinsfile: The script that tells Jenkins exactly how to automatically fetch the new certificate and re-encrypt your secrets.
  - master.key: The secret key the Sealed Secrets system uses to unlock your original secrets.
  - new-cert.pem: The new public key used to lock up your secrets again during the re-encryption process in Jenkins.
  - private-key.pem: Possibly a key used for managing the main secret key (master.key) or other security tasks.
  - public-cert.pem: Similar to private-key.pem, likely involved in managing the security keys.
  - reencrypt.sh: A script you might run manually to help with the re-encryption, similar to what Jenkins does automatically.

    
---

## Toolchain Setup and Configuration

### 1. Jenkins

- Required Plugins:
  - Git
  - GitHub
  - Pipeline
  - SSH Agent
  - Kubernetes CLI (optional for `kubectl` integration)
  - Email Extension Plugin
  - Mailer Plugin:

#### Configuration

- Add GitHub credentials (Personal Access Token or SSH key)
- Add Kubernetes CLI credentials:
  - Store `kubeconfig` as a secret file in Jenkins
- Add Sealed Secrets public cert fetching logic in pipeline script

---

### 2. Amazon EKS

- Create an **EKS cluster** using `eksctl` or the AWS Console.
  ![WhatsApp Image 2025-05-08 at 21 37 43_1ae09569](https://github.com/user-attachments/assets/f08dd208-4880-4267-960d-eea9e0bc6033)

- Ensure the cluster is accessible via `kubectl`.
- Deploy the **Sealed Secrets controller**:
  `kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.25.0/controller.yaml`

## AWS CLI Configuration

#### Configure AWS Credentials
   - Run the following command to set up your AWS credentials:
     `aws configure`
      Enter your AWS Access Key, AWS Secret Key, Region, and Output format when prompted.
   - Update kubeconfig for EKS:
      `aws eks update-kubeconfig --name python-app-cluster --region us-west-2`
   - Deploy the Sealed Secrets controller:
     `kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.25.0/controller.yaml`
   - Verify the Deployment:
     `kubectl get pods -n kube-system`
     ![WhatsApp Image 2025-05-08 at 21 40 34_f5d1c758](https://github.com/user-attachments/assets/11243cce-34ca-4450-b938-1a0fd893f3c6)





     
