properties([
    pipelineTriggers([
        githubPush()
    ])
])

pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github-token'
        AWS_CREDENTIALS = 'aws-credentials'
        AWS_REGION = 'eu-north-1'
        CLUSTER_NAME = 'my-eks-cluster'
        KUBECONFIG = "${env.WORKSPACE}/.kube/config"
        LOG_DIR = "${env.WORKSPACE}/logs"
        REPO_DIR = "Sealedsecrets-Auto-Reencrypt"
    }

    stages {
        stage('Setup Environment') {
            steps {
                // Security: Setup secure kubeconfig
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: AWS_CREDENTIALS,
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        sh '''
                        mkdir -p ${WORKSPACE}/.kube
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region ${AWS_REGION}
                        aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
                        chmod 600 ${WORKSPACE}/.kube/config
                        '''
                    }
                }
                sh """
                mkdir -p ${LOG_DIR}
                echo "Pipeline initialized at $(date)" >> ${LOG_DIR}/security-audit.log
                """
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
                        if (fileExists("${REPO_DIR}")) {
                            dir("${REPO_DIR}") {
                                sh '''
                                git fetch --all
                                git reset --hard origin/main
                                '''
                            }
                        } else {
                            sh """
                            git clone https://${GIT_USER}:${GIT_PASS}@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git \
                                ${REPO_DIR}
                            """
                        }
                    }
                }
            }
        }

        stage('Verify Sealed Secrets Controller') {
            steps {
                script {
                    sh """
                    kubectl wait -n sealed-secrets \
                        --for=condition=ready pod \
                        -l app.kubernetes.io/name=sealed-secrets \
                        --timeout=120s > ${LOG_DIR}/controller-status.log 2>&1 || true
                    echo "Controller verification exit code: $?" >> ${LOG_DIR}/security-audit.log
                    """
                }
            }
        }

        stage('Fetch New Public Certificate') {
            steps {
                script {
                    sh """
                    kubeseal --fetch-cert \
                        --controller-name=sealed-secrets-controller \
                        --controller-namespace=sealed-secrets \
                        > new-cert.pem 2> ${LOG_DIR}/cert-fetch-errors.log
                    
                    # Security validation
                    if ! openssl x509 -in new-cert.pem -noout -checkend 0; then
                        echo "ERROR: Certificate is expired" >> ${LOG_DIR}/security-alerts.log
                        exit 1
                    fi
                    echo "Cert valid until: $(openssl x509 -in new-cert.pem -noout -enddate)" >> ${LOG_DIR}/cert-audit.log
                    """
                }
            }
        }

        stage('Decrypt + Re-encrypt') {
            steps {
                script {
                    env.SECRET_COUNT = 0
                    env.ERROR_COUNT = 0

                    def namespaces = sh(script: 'kubectl get ns -o jsonpath="{.items[*].metadata.name}"', returnStdout: true).trim().split()
                    
                    namespaces.each { ns ->
                        try {
                            def secrets = sh(script: "kubectl get sealedsecrets -n ${ns} -o name", returnStdout: true).trim()
                            if (secrets) {
                                secrets.split('\n').each { secret ->
                                    try {
                                        def secretName = secret.split('/')[1]
                                        sh """
                                        echo "[$(date +%s)] Processing ${ns}/${secretName}" >> ${LOG_DIR}/execution-trace.log
                                        
                                        # Memory-sensitive processing
                                        kubectl get secret ${secretName} -n ${ns} -o json | \
                                            kubeseal --cert new-cert.pem \
                                            --format yaml \
                                            --namespace ${ns} \
                                            > ${ns}-${secretName}.yaml 2>> ${LOG_DIR}/reencryption-errors.log
                                        
                                        # Validate output
                                        if [ ! -s "${ns}-${secretName}.yaml" ]; then
                                            echo "EMPTY_OUTPUT: ${ns}/${secretName}" >> ${LOG_DIR}/integrity-alerts.log
                                            exit 1
                                        fi
                                        """
                                        env.SECRET_COUNT = env.SECRET_COUNT.toInteger() + 1
                                    } catch (Exception e) {
                                        echo "[ERROR] ${ns}/${secret}: ${e}" >> ${LOG_DIR}/errors.log
                                        env.ERROR_COUNT = env.ERROR_COUNT.toInteger() + 1
                                    }
                                }
                            }
                        } catch (Exception e) {
                            echo "[WARN] Namespace ${ns}: ${e}" >> ${LOG_DIR}/warnings.log
                        }
                    }

                    sh """
                    echo "Re-encryption Summary:" > ${LOG_DIR}/summary.log
                    echo "Total secrets processed: ${env.SECRET_COUNT}" >> ${LOG_DIR}/summary.log
                    echo "Total errors: ${env.ERROR_COUNT}" >> ${LOG_DIR}/summary.log
                    echo "Cert Fingerprint: $(openssl x509 -in new-cert.pem -noout -fingerprint)" >> ${LOG_DIR}/summary.log
                    """
                }
            }
        }

        stage('Commit Changes') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GIT_CREDENTIALS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    script {
                        dir("${REPO_DIR}") {
                            sh '''
                            git add sealedsecrets-reencrypted/ new-cert.pem
                            if ! git diff-index --quiet HEAD --; then
                                git config user.email "amrelabbasy2003@gmail.com"
                                git config user.name "Jenkins"
                                git commit -m "Auto-reencrypted ''' + env.SECRET_COUNT + ''' SealedSecrets [ci skip]"
                                git push https://$GIT_USER:$GIT_PASS@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git main
                                echo "Pushed commit $(git rev-parse HEAD)" >> ../logs/git-audit.log
                            fi
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            // Secure cleanup
            sh """
            find . -type f \( -name '*.yaml' -o -name '*.tmp' \) -exec shred -u {} \\;
            rm -f new-cert.pem
            """
            
            // Archive logs
            archiveArtifacts artifacts: "logs/*.log"
        }
        success {
            script {
                def summary = readFile("${LOG_DIR}/summary.log")
                emailext(
                    subject: "SUCCESS: Re-encrypted ${env.SECRET_COUNT} SealedSecrets",
                    body: """
Build succeeded!

Summary:
${summary}
Console URL: ${env.BUILD_URL}console
                    """,
                    to: 'amrelabbasy2003@gmail.com',
                    mimeType: 'text/plain'
                )
            }
        }
        failure {
            script {
                def errorLog = sh(script: "tail -n 50 ${LOG_DIR}/errors.log || echo 'No error log'", returnStdout: true)
                emailext(
                    subject: "FAILED: SealedSecrets Re-encryption",
                    body: """
Build failed!

Last errors:
${errorLog}

Full logs: ${env.BUILD_URL}artifact/logs/
                    """,
                    to: 'amrelabbasy2003@gmail.com',
                    mimeType: 'text/plain'
                )
            }
        }
    }
}
