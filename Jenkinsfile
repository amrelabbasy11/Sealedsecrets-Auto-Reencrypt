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
        AWS_REGION = 'eu-north-1'   // Ensure this is the correct region for your cluster
        CLUSTER_NAME = 'my-eks-cluster'   // Replace with the name of your EKS cluster
        KUBECONFIG = "${env.HOME}/.kube/config"
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

        stage('Verify Sealed Secrets Controller') {
            steps {
                script {
                    sh '''
                    kubectl wait -n sealed-secrets \
                        --for=condition=ready pod \
                        -l app.kubernetes.io/name=sealed-secrets \
                        --timeout=120s
                    '''
                }
            }
        }

        stage('Fetch New Public Certificate') {
            steps {
                script {
                    sh '''
                    kubeseal --fetch-cert \
                        --controller-name=sealed-secrets-controller \
                        --controller-namespace=sealed-secrets \
                        > new-cert.pem
                    test -s new-cert.pem || { echo "ERROR: Failed to fetch certificate"; exit 1; }
                    '''
                }
            }
        }

        stage('Extract and Re-seal Secrets') {
            steps {
                script {
                    sh '''
                    mkdir -p sealedsecrets-reencrypted

                    for ss in $(kubectl get sealedsecrets -A -o custom-columns=":metadata.namespace,:metadata.name" --no-headers); do
                        ns=$(echo $ss | awk '{print $1}')
                        name=$(echo $ss | awk '{print $2}')

                        echo "Processing $ns/$name"

                        # Get decrypted Secret object (requires kubeseal controller to handle the decrypt/convert logic)
                        secret=$(kubectl get secret "$name" -n "$ns" -o yaml 2>/dev/null || true)

                        if [ -z "$secret" ]; then
                            echo "Secret $ns/$name not found, skipping"
                            continue
                        fi

                        # Save secret yaml
                        echo "$secret" > secret.yaml

                        # Re-seal using new public key
                        kubeseal --cert new-cert.pem \
                            --format yaml \
                            --namespace "$ns" \
                            < secret.yaml \
                            > sealedsecrets-reencrypted/${ns}-${name}.yaml

                        rm -f secret.yaml
                    done
                    '''
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
                        sh '''
                        cd Sealedsecrets-Auto-Reencrypt
                        git add sealedsecrets-reencrypted/
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
                <p>Build succeeded!</p>
                <p><b>Console URL:</b> <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                """,
                to: 'amrelabbasy2003@gmail.com',
                mimeType: 'text/html'
            )
        }
        failure {
            emailext(
                subject: "FAILED: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: """
                <p>Build failed. Check logs:</p>
                <p><a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                <p><b>Error snippet:</b><br>
                ${currentBuild.rawBuild.getLog(100).join('\n')}
                </p>
                """,
                to: 'amrelabbasy2003@gmail.com',
                mimeType: 'text/html'
            )
        }
    }
}
