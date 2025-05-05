def repo = 'Sealedsecrets-Auto-Reencrypt'

pipeline {
    agent any

    environment {
        REPO_DIR = "${WORKSPACE}/${repo}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Re-encrypt SealedSecrets') {
            steps {
                sh 'chmod +x reencrypt.sh'
                sh './reencrypt.sh > reencrypt.log'
            }
        }

        stage('Commit & Push Updated Secrets') {
            steps {
                sh '''
                  git config user.name "admin"
                  git config user.email "amrelabbasy2003@gmail.com"
                  git add sealedsecrets/
                  git diff --quiet && echo "No changes to commit" || (
                    git commit -m "Auto re-encrypt sealed secrets"
                    git push origin HEAD:main
                  )
                '''
            }
        }

        stage('Archive Logs') {
            steps {
                archiveArtifacts artifacts: 'reencrypt.log', onlyIfSuccessful: true
            }
        }

        stage('Trigger ArgoCD Sync') {
            steps {
                sh '''
                curl -X POST \
                    -H "Authorization: Bearer $ARGOCD_TOKEN" \
                    https://argocd.example.com/api/v1/applications/sealedsecrets/sync
                '''
            }
        }
    }

    post {
        failure {
            mail to: 'amrelabbasy2003@gmail.com', subject: 'SealedSecrets Re-encryption Failed', body: 'Check Jenkins logs.'
        }
    }
}
