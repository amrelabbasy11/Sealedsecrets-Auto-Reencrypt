# Sealedsecrets-Auto-Reencrypt

##  Overview

This document outlines a proposed feature to enhance the kubeseal CLI tool by automating the re-encryption of all SealedSecret resources in a Kubernetes cluster. This solution facilitates seamless rotation of the Sealed Secrets controller's public key, ensuring the security of secrets without manual intervention. The re-encryption process also ensures that secrets remain securely stored, and private keys are never exposed, offering a secure and efficient method for maintaining secrets in Kubernetes.

The project leverages a CI/CD pipeline to automate and streamline the entire process. The pipeline involves several key components to handle the encryption, logging, error reporting, and synchronization of changes across multiple environments:

### Key Components of the Solution:

#### GitHub: The central repository for storing SealedSecrets YAML files. It hosts the versioned configuration files for SealedSecrets and tracks changes made throughout the re-  encryption process.
#### Jenkins: Orchestrates the entire re-encryption process. It automates the following tasks:
  - Pulling the latest changes from the GitHub repository.
  - Fetching the latest public certificate from the SealedSecrets controller.
  - Re-encrypting all SealedSecrets using the updated certificate.
  - Logging the results and tracking any errors or issues during the process.
  - Committing and pushing changes back to the GitHub repository, ensuring version control of encrypted secrets.
  - Sending email notifications on both success and failure, including detailed logs for further analysis.
#### ArgoCD: Syncs the committed changes to the Kubernetes cluster. It ensures that the updated SealedSecrets are deployed across the cluster without manual intervention, maintaining the security and consistency of secrets.
#### EKS (AWS): The target Kubernetes environment where the SealedSecrets are managed and deployed. The solution integrates with Amazon Elastic Kubernetes Service (EKS) to  facilitate smooth interaction with the Kubernetes API and ensures that the re-encrypted secrets are propagated securely.

---

## Goals

- Automate the re-encryption of all SealedSecrets using the latest public certificate
- Integrate the process into a Jenkins CI/CD pipeline
- Store updated secrets in GitHub in a secure path (`sealedsecrets-reencrypted/`)
- Sync changes to the Kubernetes cluster using ArgoCD
- Reduce human error and increase secret rotation reliability

  
## Plan Diagram 

![WhatsApp Image 2025-05-09 at 09 20 44_63898b53](https://github.com/user-attachments/assets/f45078d8-e205-435d-b9df-4cfe6a59464d)


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


### 2. Amazon EKS
 #### Why Use Amazon EKS as Kubernetes Cluster Instead of Others?
  - EKS is managed by AWS, so you don’t worry about setup or upgrades.
  - EKS works at scale, across many machines and data centers.
  - EKS is secure and works well with other AWS services (like IAM, CloudWatch, S3).
  - EKS can save costs at scale using smart features like auto-scaling and spot instances.
    
#### Create an **EKS cluster** using `eksctl` or the AWS Console.
  
  ![WhatsApp Image 2025-05-08 at 21 37 43_1ae09569](https://github.com/user-attachments/assets/f08dd208-4880-4267-960d-eea9e0bc6033)

- Ensure the cluster is accessible via `kubectl`.
- Deploy the **Sealed Secrets controller**:
  
  `kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.25.0/controller.yaml`


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


 ### 3. ArgoCD
   - Install ArgoCD on your Kubernetes cluster.
   - Follow ArgoCD documentation to configure access:
     
     `kubectl create namespace argocd`
     `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
     
   - Configure a new ArgoCD app that watches your GitHub repo.
   - ArgoCD should auto-sync sealedsecrets-reencrypted/ to the cluster.


 ### 4. GitHub
   - Store your SealedSecrets in a repository.
   - Create a target folder for updated secrets.
   - Generate a GitHub PAT (Personal Access Token) or SSH key and add it to Jenkins.

---

## Pipeline Architecture
  - The Jenkins pipeline will automate the process of re-encrypting SealedSecrets using the latest public key from the Sealed Secrets controller. 
   It consists of the following  stages:

     ### Trigger: Developer triggers a job or webhook from GitHub.
     - Automatically triggered via GitHub webhook push events using `githubPush()`.
     - Commands:
     - 
          `properties([
                pipelineTriggers([
                    githubPush()
                ])
            ])`

     ### Fetch or Expose All Sealed Secret
      - Command used:
      `kubectl get secret ${secretName} -n ${ns} -o yaml > ${REPO_DIR}/secret.yaml`
      This command fetches the decrypted Kubernetes Secret corresponding to the SealedSecret.

     ### Fetch Cert: Jenkins fetches the latest public certificate from the Sealed Secrets controller.
      - This retrieves the controller’s public certificate needed for re-encryption.
            `kubeseal --fetch-cert \
            --controller-name=sealed-secrets-controller \
            --controller-namespace=sealed-secrets \
            > ${REPO_DIR}/new-cert.pem`
      
     ### Encrypt (Re-seal using New Certificate)
       - Command used:
         
           `kubeseal --cert ${REPO_DIR}/new-cert.pem \
              --format yaml \
              --namespace ${ns} \
              < ${REPO_DIR}/secret.yaml \
              > ${REPO_DIR}/sealedsecrets-reencrypted/${ns}-${secretName}.yaml`
         
       - This generates a new SealedSecret using the latest certificate.
       - The Output from This Stage:
         
         ![WhatsApp Image 2025-05-09 at 02 14 57_9bae1012](https://github.com/user-attachments/assets/61813aed-de6d-4ce6-91ed-aa91cc09a105)
 
     ### Git Commit of Updated SealedSecrets
       - Commands used:
         
              `git add sealedsecrets-reencrypted/
               git commit -m "Re-seal secrets using new certificate" `
         
     ### Push Changes: Re-encrypted secrets are pushed to the sealedsecrets-reencrypted/ folder in GitHub.
       - Commands Used:
         
            `push origin ${{ github.head_ref }}`

     ### ArgoCD Sync: ArgoCD auto-syncs from GitHub → EKS applies updated secrets.
     ### Post Build Actions.

   Each stage should be properly monitored, with any issues logged and reported.

### 2. Pipeline Configuration

- Install required Jenkins plugins:
  - **Git Plugin**: For interacting with GitHub.
  - **GitHub Plugin**: For pushing to GitHub.
  - **Pipeline Plugin**: For defining the pipeline stages.
  - **SSH Agent Plugin**: For handling SSH key-based authentication.
  - **Kubernetes CLI Plugin** (optional): For interacting with Kubernetes clusters using `kubectl`.

#### Logging or Reporting Mechanism
  - Jenkins Console Logs: Capture all actions in the pipeline with detailed logs.
  - Error Reporting: Any failures during the re-encryption or sync processes should be logged in Jenkins and reported. For example, you could use the following
    snippet to log errors:
     `echo "$(date): Failed to re-encrypt $SECRET_NAME" >> re-encryption-errors.log`
  - Email Notification: Email alerts can be sent on pipeline success, failure, or cancellation to notify the DevOps team. This enhances visibility and ensures rapid                 response to errors or issues in the re-encryption process.

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
  
#### Security of Private Keys
- The private keys used by the SealedSecrets controller are securely handled within the Kubernetes cluster and are never exposed in the pipeline. Only the public certificate      is fetched for re-encryption. Additionally, sensitive credentials (AWS and GitHub) are securely managed using Jenkins' credential-binding mechanisms.
- command that i used :
  ` kubeseal --fetch-cert \
         --controller-name=sealed-secrets-controller \
         --controller-namespace=sealed-secrets \
         > ${REPO_DIR}/new-cert.pem`  

#### Handling Large Numbers of SealedSecrets
- The pipeline handles SealedSecrets efficiently, processing each namespace and its secrets sequentially. For large datasets, it can be further optimized by
  introducing parallelization to handle multiple namespaces or secrets at once.


### Successful Pipeline Execution
 ![WhatsApp Image 2025-05-09 at 01 59 29_ceb55f41](https://github.com/user-attachments/assets/71546b1d-120f-4510-829e-68e9e9ed5ba8)


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

## Email Notification (Logging & Reporting)

### Purpose: Email notifications provide real-time updates on the pipeline status (e.g., success, failure, or unstable builds). This ensures quick awareness of any issues in the re-encryption process.

### To set up email notifications in Jenkins, follow these steps:

1. Access Jenkins System Settings
   - Log in to your Jenkins dashboard.
   - Go to Manage Jenkins > System.
2. Configure SMTP Serve
    1. Scroll down to the E-mail Notification section.

    2. Fill in the following details:
        - SMTP Server: smtp.gmail.com
        - User Name: Your Gmail address (e.g., amrelabbasy2003@gmail.com).
        - Password: Your Gmail app password (generate one from your Google Account settings if needed).
        - Use SSL: Enable this option.
        - SMTP Port: Use 465 for SSL or 587 for TLS.
   - Note:
    SSL (Port 465): Encrypts the connection using SSL.
    TLS (Port 587): Encrypts the connection using TLS (preferred for modern setups).
   3. Click Apply and Save.
3. Test Email Configuration
    1. In the E-mail Notification section, click Test configuration by sending a test email.
    2. Enter your email address and click Test configuration.
    3. Ensure you receive a test email to confirm the setup is working.
     - Test Image : 
    ![WhatsApp Image 2025-05-09 at 01 31 40_53477d63](https://github.com/user-attachments/assets/79ce7068-53f8-44b6-9320-22bae4543ea3)

4. Install the Email Extension Plugin
    1. Go to Manage Jenkins > Manage Plugins.
    2. In the Available tab, search for Email Extension Plugin.
    3. Install the plugin and restart Jenkins if prompted.
5. Configure Email Notifications in Your Pipeline
    Add the emailext step in your Jenkinsfile to send email notifications.
6. Verify Email Notifications
    1. Run your Jenkins pipeline.
    2. Check your email inbox for notifications based on the pipeline's success or failure.
       - Success Image:
         ![WhatsApp Image 2025-05-09 at 01 34 22_5c497063](https://github.com/user-attachments/assets/fd69c7fb-b1af-46c3-80da-31fc776fbb30)

      - Debug the email notification to ensure that failure works by comment line `//`:
        ![WhatsApp Image 2025-05-09 at 03 56 14_abaa99b0](https://github.com/user-attachments/assets/096eb6de-ba8c-4325-8174-0d7858e3dd5a)


- Note
  If the email is not sent even after following the steps you mentioned, try adding your email as a credential in Jenkins.
   Here’s how you can do it : 
   Step 1: Add Your Email as a Credential in Jenkins -> Open Jenkins Dashboard -> Go to Jenkins Home -> Click on Manage Jenkins. 
           Go to Credentials Management
           Click on Manage Credentials -> Select (Global credentials).

    Add a New Credential
        Click on Add Credentials.
        In Kind, select Username and password.
        Username: Enter your email (e.g., amrelabbasy2003@gmail.com).
        Password: Enter your email password (or an App Password if using Gmail).
        ID: Give it an identifier like email-credentials.
        Click OK to save.
  
---
## Configuring ArgoCD and Connecting to GitHub Repository
 ### What Argocd does:
  - Syncs SealedSecrets - Automatically deploys encrypted secrets from Git to Kubernetes
  - Monitors Health - Reports if secrets fail to decrypt or deploy properly
  - Triggers Alerts - Notifies when secrets become "Degraded" for quick troubleshooting
    
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

---
## Conclusion
The proposed feature to automate the re-encryption of all SealedSecret resources in a Kubernetes cluster provides a highly efficient, secure, and scalable solution for managing secrets. By leveraging a robust CI/CD pipeline with tools such as GitHub, Jenkins, ArgoCD, and AWS EKS, the solution ensures that SealedSecrets remain up-to-date with the latest encryption standards while maintaining the integrity and security of sensitive data.

The automation of this process not only reduces manual intervention but also enhances the overall security posture of the Kubernetes environment by simplifying the rotation of public keys and eliminating the risk of key exposure. Additionally, with integrated error handling, logging, and notifications, the pipeline provides visibility and control over the re-encryption process, ensuring that potential issues are promptly addressed.

The proposed architecture allows for efficient scaling, handling both small and large numbers of secrets, with future optimizations like parallel processing enabling even greater performance in large clusters. Overall, this solution aligns with best practices in secret management and continuous delivery, enhancing both security and operational efficiency in managing Kubernetes secrets.
