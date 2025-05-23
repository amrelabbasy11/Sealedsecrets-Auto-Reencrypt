# Kubeseal Auto-Re-encryption Subsystem.

##  Overview

When building applications like websites that connect to databases, one of the most common challenges is managing sensitive data like usernames and passwords. If these credentials are stored directly in the code or a public repository (like on GitHub), anyone who has access to the repository can also access those credentials. This is a major security risk because it would allow unauthorized access to the database or other sensitive resources.
Kubernetes tries to help with this by using Secrets, a way to securely store sensitive information. However, Kubernetes Secrets are only base64-encoded, which means they aren’t truly encrypted. Anyone with access to the secrets can easily decode them, which doesn’t provide real protection. So, what’s the better solution? Asymmetric encryption.
Asymmetric encryption works with two keys: a public key and a private key. The idea is simple: encrypt the secrets with the public key, and only someone who holds the private key can decrypt them. This way, even if someone gets hold of the encrypted secrets, they can’t read them without access to the private key — which stays safe within the Kubernetes cluster.
Now, here's where things can get tricky: the encryption keys used in Kubernetes can expire or need to be rotated for security purposes. Without a system in place to automate this key rotation, it can quickly become a manual and error-prone process. That’s where we need a solution to keep everything secure without a lot of hassle.
The proposed solution here is to automate the re-encryption of all SealedSecret resources in Kubernetes. This would enhance the kubeseal CLI tool and allow it to automatically handle the rotation of the Sealed Secrets controller's public key. This way, all secrets stay securely encrypted, and the private keys are never exposed, ensuring a much more streamlined and secure process for managing secrets in Kubernetes.

In the next sections, I'll break down how this works in practice, step by step, and explain how automating this process can save time, reduce human error, and keep everything secure in your Kubernetes environment.

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
![Add a subheading(1)](https://github.com/user-attachments/assets/bbf413a8-9d50-4d5d-8900-5d958c88ca86)



---

## Project Layout
  - infrastructure/argocd/sealedsecrets-app.yaml: File for Argo CD, a tool to automatically deploy and manage your Sealed Secrets in your Kubernetes setup.
  - sealedsecrets-reencrypted/: Folder where the updated, re-encrypted secret files are stored after Jenkins processes them.
  - Jenkinsfile: The script that tells Jenkins exactly how to automatically fetch the new certificate and re-encrypt your secrets.
  - master.key: The secret key the Sealed Secrets system uses to unlock your original secrets.
  - new-cert.pem: The new public key used to lock up your secrets again during the re-encryption process in Jenkins.
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

- Configuration
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
    #### Commands Used:
          `properties([
                pipelineTriggers([
                    githubPush()
                ])
            ])`

     ###  Re-encrypt Stage
      #### Commands Used:
        `kubeseal --cert new-cert.pem \
        --format yaml \
        --namespace ${ns} \
        < input.yaml > ${ns}-${secretName}.yaml \
        2>> ${LOG_DIR}/reencryption-errors.log`

      #### Enhanced Features
       - Logging
         #### Commands Used:
         `echo "Processing ${ns}/${secretName} with cert $(openssl x509 -in new-cert.pem -noout -fingerprint)" >> ${LOG_DIR}/process.log`

      - Security (Memory-only processing)
      #### - Commands Used:
          
        `kubectl get secret ${name} -n ${ns} -o json | kubeseal --cert <(cat new-cert.pem) > output.yaml`


      ### Fetch Certificate
      - Jenkins fetches the latest public certificate from the Sealed Secrets controller.
      - This retrieves the controller’s public certificate needed for re-encryption.
        
            `kubeseal --fetch-cert \
            --controller-name=sealed-secrets-controller \
            --controller-namespace=sealed-secrets \
            > ${REPO_DIR}/new-cert.pem`

     - Security Check:
      #### Commands Used:
      `openssl x509 -in new-cert.pem -noout -text >> ${LOG_DIR}/cert-audit.log`
      
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

    #### Future Scalability: This pipeline is designed to efficiently handle large-scale secret re-encryption through parallel processing and batched operations when needed.

### Successful Pipeline Execution
 ![WhatsApp Image 2025-05-09 at 01 59 29_ceb55f41](https://github.com/user-attachments/assets/71546b1d-120f-4510-829e-68e9e9ed5ba8)


### jenkins-build-artifacts
  ![WhatsApp Image 2025-05-08 at 19 10 53_1a75c8b7](https://github.com/user-attachments/assets/16f0d888-58e1-47fc-ad64-be922824e5ed)

---
# Authentication & Access Control

### 1. Jenkins and AWS EKS
- Overview: To link Jenkins with AWS EKS, you need to set up AWS credentials, configure the Kubernetes CLI (`kubectl`), and ensure Jenkins has the required access.

#### Steps to Link Jenkins with AWS EKS:
1. Generate AWS Access and Secret Keys:
   - Sign in to your AWS account.
   - Navigate to **IAM** (Identity and Access Management).
   - Go to **Users** → Select your user → **Security Credentials** → **Create access key**.
   - Save the **Access Key ID** and **Secret Access Key**.

2. Set AWS Credentials in Jenkins:
   - In Jenkins, go to **Manage Jenkins** → **Manage Credentials** → **(Global)**.
   - Click **Add Credentials** → Select **"AWS Credentials"**.
   - Enter the **Access Key ID** and **Secret Access Key** from AWS.

3. Install and Configure Kubernetes CLI (`kubectl`) on Jenkins:
   - Ensure `kubectl` is installed on Jenkins agents.
   - In Jenkins, use a pipeline step to configure `kubectl` to interact with your EKS cluster.
   - Example:
     ```bash
     aws eks --region eu-north-1 update-kubeconfig --name my-eks-cluster
     ```
### 2. Jenkins and GitHub

- Overview: To link Jenkins with GitHub, you can use a **GitHub Personal Access Token (PAT)** to authenticate Jenkins to access repositories.

#### Steps to Link Jenkins with GitHub:
1. Generate GitHub Personal Access Token (PAT):
   - Go to **GitHub Developer Settings**.
   - Click **Generate new token**.
   - Select **repo**, **workflow**, and other required scopes.
   - Copy the generated **PAT**.

2. Set GitHub Token in Jenkins:
   - In Jenkins, go to **Manage Jenkins** → **Manage Credentials** → **(Global)**.
   - Click **Add Credentials** → Select **"Secret Text"**.
   - Paste the GitHub PAT into the **Secret** field and give it a **ID** (e.g., `github-token`).

3. Configure GitHub Webhook:
   - In your GitHub repository, go to **Settings** → **Webhooks** → **Add webhook**.
   - Set the **Payload URL** to your Jenkins server's webhook URL (`http://192.168.52.130:8080/github-webhook/`).
   - Choose **Just the push event** for triggers.

### 3. ArgoCD and GitHub

- Overview: ArgoCD integrates with GitHub to enable automated deployment to Kubernetes based on changes pushed to a GitHub repository.

#### Steps to Link ArgoCD with GitHub:
1. Generate GitHub Personal Access Token (PAT):
   - Follow the same steps as described in the Jenkins-GitHub integration section to generate a PAT with the **repo** and **admin:repo_hook** scopes.

2. Set GitHub Token in ArgoCD:
   - Log in to the ArgoCD UI.
   - Go to **Settings** → **Repositories** → **Connect Repo**.
   - Select **GitHub** as the repository type and paste the **GitHub PAT** into the authentication section.

3. Set up ArgoCD to Sync with GitHub:
   - In the ArgoCD UI, go to **Applications** → **Create Application**.
   - Set the **Source** to your GitHub repository and configure the **Destination** (your Kubernetes cluster).
   - Enable **Auto-sync** to automatically sync changes from GitHub to the cluster when changes are pushed.

#### For Secuirity and Authentication: Use sealed secrets to ensure only the controller can decrypt the secrets

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
Managing sensitive credentials securely in Kubernetes environments is critical, especially at scale and across dynamic infrastructures. While Kubernetes Secrets provide a starting point, their base64 encoding falls short of real encryption. This project enhances the security posture of Kubernetes clusters by automating the re-encryption of SealedSecrets using updated public certificates, addressing the crucial need for seamless secret rotation.

By integrating Jenkins for automation, GitHub for version control, ArgoCD for continuous deployment, and EKS for scalable infrastructure, this solution creates a robust, hands-off pipeline for managing secrets securely. It eliminates manual intervention, reduces human error, and ensures that applications always use up-to-date, encrypted credentials.

With this automated SealedSecrets re-encryption pipeline in place, teams can confidently rotate encryption keys without service disruption—making their Kubernetes deployments more resilient, secure, and compliant with modern DevOps practices.
