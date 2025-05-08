pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        GIT_PASS = credentials('git-password')
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Setup Environment') {
            steps {
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    mkdir -p /var/lib/jenkins/.kube
                    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                    aws configure set region eu-north-1
                    aws eks update-kubeconfig --name my-eks-cluster --region eu-north-1
                    '''
                }
            }
        }

        stage('Git Clone') {
            steps {
                withCredentials([string(credentialsId: 'git-password', variable: 'GIT_PASS')]) {
                    sh '''
                    git fetch --all
                    git reset --hard origin/main
                    '''
                }
            }
        }

        stage('Wait for Sealed Secrets Controller') {
            steps {
                sh '''
                kubectl wait -n sealed-secrets --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets --timeout=120s
                '''
            }
        }

        stage('Fetch Latest Public Key') {
            steps {
                sh '''
                kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=sealed-secrets
                test -s new-cert.pem
                '''
            }
        }

        stage('Re-Encrypt SealedSecrets') {
            steps {
                sh '''
                echo [INFO] Starting re-encryption process
                mkdir -p sealedsecrets-reencrypted
                find . -name "*.sealedsecret" -exec kubeseal --cert new-cert.pem -o yaml --re-encrypt {} > sealedsecrets-reencrypted/$(basename {} .sealedsecret).yaml ;
                '''
            }
        }

        stage('Commit and Push') {
            steps {
                withCredentials([string(credentialsId: 'git-password', variable: 'GIT_PASS')]) {
                    script {
                        sh '''
                        git config user.name Jenkins
                        git config user.email jenkins@example.com
                        git add sealedsecrets-reencrypted/*.yaml
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
            archiveArtifacts allowEmptyArchive: true, artifacts: '**/sealedsecrets-reencrypted/*.yaml'
            cleanWs()
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
