# Sealedsecrets-Auto-Reencrypt

## Overview
This project automates the process of fetching the latest public key from the Sealed Secrets controller on an AWS EKS cluster and re-sealing all existing SealedSecret Kubernetes objects using the new public key. It integrates GitHub, Jenkins, ArgoCD, and EKS to ensure a secure, fully automated GitOps workflow.
