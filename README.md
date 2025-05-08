# Sealedsecrets-Auto-Reencrypt

##  Overview

This document outlines a proposed feature to enhance the kubeseal CLI tool by automating the re-encryption of all SealedSecret resources in a Kubernetes cluster. This solution facilitates seamless rotation of the Sealed Secrets controller's public key, ensuring the security of secrets without manual intervention. The re-encryption process also ensures that secrets remain securely stored, and private keys are never exposed, offering a secure and efficient method for maintaining secrets in Kubernetes.

The project leverages a CI/CD pipeline to automate and streamline the entire process. The pipeline involves several key components to handle the encryption, logging, error reporting, and synchronization of changes across multiple environments:

### Key Components of the Solution:

- GitHub: The central repository for storing SealedSecrets YAML files. It hosts the versioned configuration files for SealedSecrets and tracks changes made throughout the re-  encryption process.
- Jenkins: Orchestrates the entire re-encryption process. It automates the following tasks:
- Pulling the latest changes from the GitHub repository.
- Fetching the latest public certificate from the SealedSecrets controller.
- Re-encrypting all SealedSecrets using the updated certificate.
- Logging the results and tracking any errors or issues during the process.
- Committing and pushing changes back to the GitHub repository, ensuring version control of encrypted secrets.
- Sending email notifications on both success and failure, including detailed logs for further analysis.
- ArgoCD: Syncs the committed changes to the Kubernetes cluster. It ensures that the updated SealedSecrets are deployed across the cluster without manual intervention, maintaining the security and consistency of secrets.
- EKS (AWS): The target Kubernetes environment where the SealedSecrets are managed and deployed. The solution integrates with Amazon Elastic Kubernetes Service (EKS) to  facilitate smooth interaction with the Kubernetes API and ensures that the re-encrypted secrets are propagated securely.

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
  - Mailer Plugin

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
---
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
---
 ### 3. ArgoCD
   - Install ArgoCD on your Kubernetes cluster.
   - Follow ArgoCD documentation to configure access:
     `kubectl create namespace argocd`
     `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
   - Configure a new ArgoCD app that watches your GitHub repo.
   - ArgoCD should auto-sync sealedsecrets-reencrypted/ to the cluster.
---
 ### 4. GitHub
   - Store your SealedSecrets in a repository.
   - Create a target folder for updated secrets.
   - Generate a GitHub PAT (Personal Access Token) or SSH key and add it to Jenkins.

---


## Pipeline Architecture
  - The Jenkins pipeline will automate the process of re-encrypting SealedSecrets using the latest public key from the Sealed Secrets controller. 
   It consists of the following  stages:

     1. Trigger: Developer triggers a job or webhook from GitHub.
     - Automatically triggered via GitHub webhook push events using `githubPush()`.
     2. Fetch Cert: Jenkins fetches the latest public certificate from the Sealed Secrets controller.
       `kubeseal --fetch-cert --controller-namespace kube-system --controller-name sealed-secrets-controller > new-cert.pem`
     3. Decrypt + Re-encrypt: Each secret is decrypted and re-encrypted using the new cert.
     4. Push Changes: Re-encrypted secrets are pushed to the sealedsecrets-reencrypted/ folder in GitHub.
     5. ArgoCD Sync: ArgoCD auto-syncs from GitHub → EKS applies updated secrets.
     6. Post Build Actions.

   Each stage should be properly monitored, with any issues logged and reported.
---
### 2. Pipeline Configuration

- Install required Jenkins plugins:
  - **Git Plugin**: For interacting with GitHub.
  - **GitHub Plugin**: For pushing to GitHub.
  - **Pipeline Plugin**: For defining the pipeline stages.
  - **SSH Agent Plugin**: For handling SSH key-based authentication.
  - **Kubernetes CLI Plugin** (optional): For interacting with Kubernetes clusters using `kubectl`.
---    
#### Logging or Reporting Mechanism
  - Jenkins Console Logs: Capture all actions in the pipeline with detailed logs.
  - Error Reporting: Any failures during the re-encryption or sync processes should be logged in Jenkins and reported. For example, you could use the following
    snippet to log errors:
     `echo "$(date): Failed to re-encrypt $SECRET_NAME" >> re-encryption-errors.log`
---   
#### Ensuring the Security of Private Keys
- The pipeline logs the entire re-encryption process, including detailed information on each secret processed, warnings, errors, and a summary of the re-encryption status.        These logs are saved in the logs directory and are part of the artifacts archived at the end of the build. Logs are also included in the email notifications for
  both success and failure, allowing detailed tracking of the re-encryption process.
- command that i used :  
   
    `echo "[INFO] Processing ${ns}/${secretName}" >> ${LOG_DIR}/reencryption.log`
    `# Capturing any errors during re-encryption and logging to a separate file`
    `kubeseal --cert ${REPO_DIR}/new-cert.pem \
             --format yaml \
             --namespace ${ns} \
             < ${REPO_DIR}/secret.yaml \
             > ${REPO_DIR}/sealedsecrets-reencrypted/${ns}-${secretName}.yaml 2>> ${LOG_DIR}/reencryption-errors.log`
    `# Final summary of the process`
    `echo "Re-encryption Summary:" > ${LOG_DIR}/summary.log`
    `echo "Total secrets processed: ${totalSecretsProcessed}" >> ${LOG_DIR}/summary.log`
    `echo "Total errors encountered: ${totalErrors}" >> ${LOG_DIR}/summary.log`
---
#### Security of Private Keys
- The private keys used by the SealedSecrets controller are securely handled within the Kubernetes cluster and are never exposed in the pipeline. Only the public certificate      is fetched for re-encryption. Additionally, sensitive credentials (AWS and GitHub) are securely managed using Jenkins' credential-binding mechanisms.
- command that i used :
  ` kubeseal --fetch-cert \
         --controller-name=sealed-secrets-controller \
         --controller-namespace=sealed-secrets \
         > ${REPO_DIR}/new-cert.pem`  
---
#### Handling Large Numbers of SealedSecrets
- The pipeline handles SealedSecrets efficiently, processing each namespace and its secrets sequentially. For large datasets, it can be further optimized by
  introducing parallelization to handle multiple namespaces or secrets at once.

---

### Successful Pipeline Execution
   ![WhatsApp Image 2025-05-07 at 20 12 17_64fb9900](https://github.com/user-attachments/assets/00f1b299-a8e7-4993-b437-615866606530)

### jenkins-build-artifacts
  ![WhatsApp Image 2025-05-08 at 19 10 53_1a75c8b7](https://github.com/user-attachments/assets/16f0d888-58e1-47fc-ad64-be922824e5ed)


---
## Authentication & Security
 ### Kubernetes 
   - Use sealed secrets to ensure only the controller can decrypt the secrets
   - Limit kubeseal access to CI-only environments

 ### GitHub
   - Store tokens/keys in Jenkins as secrets

 ### Jenkins
   - Rotate stored credentials periodically
   - Isolate this pipeline in a folder with limited access

 ### ArgoCD:
   - Enable SSO or role-based access
   - Limit write access to only sync and read secrets


---

## Configuring ArgoCD and Connecting to GitHub Repository

To enable GitOps with ArgoCD, follow these steps to connect your GitHub repository containing Kubernetes manifests:

### Step 1: Login to ArgoCD Web UI

- Navigate to the ArgoCD Web UI (`http://localhost:8082`)  
- Login using the admin credentials

### Step 2: Connect GitHub Repository

1. In the left sidebar, go to **Settings > Repositories**
2. Click **Connect Repo using HTTPS**
3. Fill the details:

- **Repository URL**: `https://github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git`
- **Username**: Your GitHub username like `amrelabbasy11`
- **Password/Token**: Your GitHub personal access token (with `repo` permission)

### Step 3: Create a New Application

1. Go to **Applications > New App**
2. Fill in:

- **Application Name**: `sealedsecrets-app`
- **Project**: `default`
- **Sync Policy**: Manual or Automatic (recommended: Automatic)
- **Repository URL**: Same as above
- **Revision**: `main`
- **Path**: Path inside the repo (`sealedsecrets-reencrypted`)

### Step 4: Sync the Application

- Click the newly created app → Click **Sync**
- It will deploy the resources defined in your repo to the cluster

### Result & sealedsecrets-app.yaml
- Once configured, every change pushed by Jenkins to the GitHub repository will automatically be synced by ArgoCD (if auto-sync is enabled).
![WhatsApp Image 2025-05-08 at 23 11 41_87040ca4](https://github.com/user-attachments/assets/4c5d57bc-6c6c-4819-8495-896bb58f2a8d)


