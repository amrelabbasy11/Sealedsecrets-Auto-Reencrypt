properties([
    pipelineTriggers([
        githubPush()  // Trigger on GitHub push event
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
        ARTIFACT_DIR = "${env.WORKSPACE}/artifacts"
    }

    stages {
        stage('Setup Environment') {
            steps {
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
                        '''
                    }
                }
                sh """
                mkdir -p ${LOG_DIR}
                mkdir -p ${ARTIFACT_DIR}
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
                                sh 'git fetch --all'
                                sh 'git reset --hard origin/main'
                            }
                        } else {
                            sh """
                            git clone https://${GIT_USER}:${GIT_PASS}@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git \
                                ${REPO_DIR}
                            """
                        }
                        // Create necessary directories in the repo
                        sh """
                        mkdir -p ${REPO_DIR}/sealedsecrets-reencrypted
                        """
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
                        > ${REPO_DIR}/new-cert.pem 2> ${LOG_DIR}/cert-fetch-errors.log
                    test -s ${REPO_DIR}/new-cert.pem || { 
                        echo "ERROR: Failed to fetch certificate" | tee -a ${LOG_DIR}/errors.log
                        exit 1 
                    }
                    """
                }
            }
        }

        stage('Decrypt + Re-encrypt') {
            steps {
                script {
                    // env.SECRET_COUNT = 0
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
                                        echo "[INFO] Processing ${ns}/${secretName}" >> ${LOG_DIR}/reencryption.log
                                        kubectl get secret ${secretName} -n ${ns} -o yaml > ${REPO_DIR}/secret.yaml 2>> ${LOG_DIR}/warnings.log
                                        kubeseal --cert ${REPO_DIR}/new-cert.pem \
                                            --format yaml \
                                            --namespace ${ns} \
                                            < ${REPO_DIR}/secret.yaml \
                                            > ${REPO_DIR}/sealedsecrets-reencrypted/${ns}-${secretName}.yaml 2>> ${LOG_DIR}/reencryption-errors.log
                                        rm -f ${REPO_DIR}/secret.yaml
                                        """
                                        env.SECRET_COUNT = env.SECRET_COUNT.toInteger() + 1
                                    } catch (Exception e) {
                                        echo "[ERROR] Failed to process ${ns}/${secret}: ${e}" >> ${LOG_DIR}/errors.log
                                        env.ERROR_COUNT = env.ERROR_COUNT.toInteger() + 1
                                    }
                                }
                            }
                        } catch (Exception e) {
                            echo "[WARN] Error processing namespace ${ns}: ${e}" >> ${LOG_DIR}/warnings.log
                        }
                    }

                    sh """
                    echo "Re-encryption Summary:" > ${LOG_DIR}/summary.log
                    echo "=====================" >> ${LOG_DIR}/summary.log
                    echo "Total secrets processed: ${env.SECRET_COUNT}" >> ${LOG_DIR}/summary.log
                    echo "Total errors: ${env.ERROR_COUNT}" >> ${LOG_DIR}/summary.log
                    echo "Details in ${LOG_DIR}/reencryption.log" >> ${LOG_DIR}/summary.log
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
                            // Securely handle the git push without string interpolation
                            sh '''
                            git add sealedsecrets-reencrypted/ new-cert.pem
                            if ! git diff-index --quiet HEAD --; then
                                git config user.email "amrelabbasy2003@gmail.com"
                                git config user.name "Jenkins"
                                git commit -m "Auto-reencrypted ''' + env.SECRET_COUNT + ''' SealedSecrets [ci skip]"
                                git push https://$GIT_USER:$GIT_PASS@github.com/amrelabbasy11/Sealedsecrets-Auto-Reencrypt.git main
                            else
                                echo "No changes to commit" >> ../logs/summary.log
                            fi
                            '''
                        }
                        // Copy logs into the artifact directory
                        sh """
                        cp -r ${LOG_DIR} ${ARTIFACT_DIR}/logs || true
                        cp ${REPO_DIR}/new-cert.pem ${ARTIFACT_DIR}/ || true
                        cp ${REPO_DIR}/sealedsecrets-reencrypted/*.yaml ${ARTIFACT_DIR}/ || true
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            // Archive all artifacts from the dedicated artifact directory
            archiveArtifacts artifacts: "artifacts/**", allowEmptyArchive: true
            
            // Cleanup
            sh """
            rm -f "${REPO_DIR}/secret.yaml" || true
            rm -f "${REPO_DIR}/new-cert.pem" || true
            """
        }
        success {
            script {
                def summary = readFile("${LOG_DIR}/summary.log")
                echo "Build succeeded!\n${summary}"
                try {
                    emailext(
                        subject: "SUCCESS: Re-encrypted ${env.SECRET_COUNT} SealedSecrets",
                        body: """
                        <p>Build succeeded!</p>
                        <p><b>Summary:</b></p>
                        <pre>${summary}</pre>
                        <p><b>Console URL:</b> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                        """,
                        to: 'amrelabbasy2003@gmail.com',
                        mimeType: 'text/html'
                    )
                } catch (Exception e) {
                    echo "Failed to send email: ${e}"
                }
            }
        }
        failure {
            script {
                def errorLog = sh(script: "tail -n 50 ${LOG_DIR}/errors.log || echo 'No error log'", returnStdout: true)
                echo "Build failed.\nLast errors:\n${errorLog}"
                try {
                    emailext(
                        subject: "FAILED: SealedSecrets Re-encryption",
                        body: """
                        <p>Build failed.</p>
                        <p><b>Last errors:</b></p>
                        <pre>${errorLog}</pre>
                        <p><b>Full logs:</b> <a href="${env.BUILD_URL}artifact/artifacts/logs/">Download</a></p>
                        """,
                        to: 'amrelabbasy2003@gmail.com',
                        mimeType: 'text/html'
                    )
                } catch (Exception e) {
                    echo "Failed to send email: ${e}"
                }
            }
        }
    }
}
