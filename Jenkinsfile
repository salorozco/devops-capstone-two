pipeline {
  agent { label 'worker' }

  environment {
    CONTAINER_NAME = 'capstone-nginx'
    APP_PORT = '8081'
  }

  stages {
    stage('Validate') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euo pipefail
          : "${APP_SERVER_HOST:?APP_SERVER_HOST is required}"
          : "${IMAGE_REPOSITORY:?IMAGE_REPOSITORY is required}"
          test -f app/index.html
          test -f Dockerfile
          test -f scripts/deploy_app.sh
        '''
      }
    }

    stage('Prepare Image Tag') {
      steps {
        script {
          env.IMAGE_TAG = sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim()
          env.IMAGE_REF = "${env.IMAGE_REPOSITORY}:${env.IMAGE_TAG}"
          env.IMAGE_LATEST_REF = "${env.IMAGE_REPOSITORY}:latest"
        }
        sh '''#!/usr/bin/env bash
          set -euo pipefail
          echo "Image tag: ${IMAGE_TAG}"
          echo "Image ref: ${IMAGE_REF}"
        '''
      }
    }

    stage('Build and Push Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')]) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail
            trap 'docker logout >/dev/null 2>&1 || true' EXIT

            docker build -t "$IMAGE_REF" -t "$IMAGE_LATEST_REF" .
            printf '%s\n' "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
            docker push "$IMAGE_REF"
            docker push "$IMAGE_LATEST_REF"
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'agent-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
          usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')
        ]) {
          sh 'bash scripts/deploy_app.sh'
        }
      }
    }
  }
}
