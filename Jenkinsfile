properties([
    pipelineTriggers([
        githubPush()
    ])
])

pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github-token' // Replace with actual GitHub credentials ID
        AWS_CREDENTIALS = 'aws-credentials' // Replace with actual AWS credentials ID
        AWS_REGION = 'eu-north-1'
        CLUSTER_NAME = 'my-eks-cluster'
        KUBECONFIG = "${env.HOME}/.kube/config"
        LOG_FILE = 'reencryption-log.txt'
    }

    stages {
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
                sh '''
                kubectl wait -n sealed-secrets \
                    --for=condition=ready pod \
                    -l app.kubernetes.io/name=sealed-secrets \
                    --timeout=120s
                '''
            }
        }

        stage('Fetch Latest Public Key') {
            steps {
                sh '''
                kubeseal --fetch-cert \
                    --controller-name=sealed-secrets-controller \
                    --controller-namespace=sealed-secrets \
                    > new-cert.pem
                test -s new-cert.pem || { echo "ERROR: Failed to fetch certificate"; exit 1; }
                '''
            }
        }

        stage('Re-Encrypt SealedSecrets') {
            steps {
                script {
                    sh '''
                    echo "[INFO] Starting re-encryption process" > ${LOG_FILE}
                    mkdir -p sealedsecrets-reencrypted

                    kubectl get sealedsecrets -A -o json | jq -c '.items[]' | while read ss; do
                        ns=$(echo $ss | jq -r '.metadata.namespace')
                        name=$(echo $ss | jq -r '.metadata.name')

                        echo "[INFO] Processing $ns/$name" | tee -a ${LOG_FILE}

                        # Attempt to retrieve original Secret
                        secret=$(kubeseal --re-encrypt \
                            --controller-namespace=sealed-secrets \
                            --controller-name=sealed-secrets-controller \
                            --fetch-cert \
                            --cert=new-cert.pem \
                            --format yaml \
                            --namespace "$ns" \
                            < <(kubectl get sealedsecret "$name" -n "$ns" -o yaml) 2>>${LOG_FILE})

                        if [ -z "$secret" ]; then
                            echo "[WARN] Could not re-encrypt $ns/$name" | tee -a ${LOG_FILE}
                            continue
                        fi

                        echo "$secret" > sealedsecrets-reencrypted/${ns}-${name}.yaml

                        # Apply updated SealedSecret
                        kubectl apply -f sealedsecrets-reencrypted/${ns}-${name}.yaml >>${LOG_FILE} 2>&1
                    done

                    echo "[INFO] Re-encryption complete" | tee -a ${LOG_FILE}
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
                        cd Sealedsecrets-Auto-Reencrypt
                        git config user.email "ci@sealedsecrets.com"
                        git config user.name "Jenkins CI"
                        git add sealedsecrets-reencrypted/
                        git add ${LOG_FILE}
                        if ! git diff-index --quiet HEAD --; then
                            git commit -m "Auto-reencrypted SealedSecrets with latest cert [ci skip]"
                            git push https://${GIT_USER}:${GIT_PASS}@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git main
                        else
                            echo "No changes to commit"
                        fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
            archiveArtifacts artifacts: 'new-cert.pem,sealedsecrets-reencrypted/*.yaml'
        }

        success {
            emailext(
                subject: "SUCCESS: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: """
                <p>SealedSecrets were successfully re-encrypted and updated.</p>
                <p><b>Console Output:</b> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                """,
                to: 'amrelabbasy2003@gmail.com',
                mimeType: 'text/html'
            )
        }

        failure {
            emailext(
                subject: "FAILED: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: """
                <p>Re-encryption failed. Please check the logs.</p>
                <p><a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                <p><b>Log Extract:</b><br>
                ${currentBuild.rawBuild.getLog(50).join('<br>')}
                </p>
                """,
                to: 'amrelabbasy2003@gmail.com',
                mimeType: 'text/html'
            )
        }
    }
}
