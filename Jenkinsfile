pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id') // Set the AWS credentials
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key') // Set the AWS secret key
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
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

        stage('Post Actions') {
            steps {
                script {
                    // Ensure the artifacts are archived after all steps
                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/sealedsecrets-reencrypted/*.yaml', onlyIfSuccessful: true
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
