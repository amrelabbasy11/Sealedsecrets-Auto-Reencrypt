pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github-token'  // Replace with your GitHub credentials ID
        AWS_CREDENTIALS = 'aws-credentials'  // Replace with your AWS credentials ID
        AWS_REGION = 'eu-north-1'
        CLUSTER_NAME = 'my-eks-cluster'
        KUBECONFIG = "${env.HOME}/.kube/config"
        LOG_FILE = 'reencryption-log.txt'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Setup Environment') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: AWS_CREDENTIALS
                ]]) {
                    script {
                        sh '''
                        mkdir -p ~/.kube
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region ${AWS_REGION}
                        aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
                        '''
                    }
                }
            }
        }

        stage('Git Clone') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GIT_CREDENTIALS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    script {
                        def repoDir = 'Sealedsecrets-Auto-Reencrypt'
                        if (fileExists(repoDir)) {
                            dir(repoDir) {
                                sh 'git fetch --all'
                                sh 'git reset --hard origin/main'
                            }
                        } else {
                            sh "git clone https://${GIT_USER}:${GIT_PASS}@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git"
                        }
                    }
                }
            }
        }

        stage('Wait for Sealed Secrets Controller') {
            steps {
                script {
                    sh 'kubectl wait -n sealed-secrets --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets --timeout=120s'
                }
            }
        }

        stage('Fetch Latest Public Key') {
            steps {
                script {
                    sh '''
                    kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=sealed-secrets
                    test -s new-cert.pem
                    '''
                }
            }
        }

        stage('Re-Encrypt SealedSecrets') {
            steps {
                script {
                    sh '''
                    echo "[INFO] Starting re-encryption process"
                    mkdir -p sealedsecrets-reencrypted
                    for secret in $(find . -name '*.sealedsecret'); do
                        kubeseal --cert new-cert.pem -o yaml < $secret > sealedsecrets-reencrypted/$(basename $secret)
                    done
                    '''
                }
            }
        }

        stage('Commit and Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GIT_CREDENTIALS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    script {
                        sh '''
                        git config user.name "Jenkins"
                        git config user.email "jenkins@example.com"
                        git add sealedsecrets-reencrypted/*
                        git commit -m "Re-encrypted Sealed Secrets"
                        git push origin main
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'sealedsecrets-reencrypted/*', allowEmptyArchive: true
            cleanWs()
        }

        success {
            echo "Pipeline executed successfully."
        }

        failure {
            echo "Pipeline failed."
            // Handle failure, e.g., send notifications, logs, etc.
        }
    }
}
