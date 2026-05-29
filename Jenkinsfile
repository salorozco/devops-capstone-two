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

    stage('Build Image') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euo pipefail
          docker build -t "$IMAGE_REF" -t "$IMAGE_LATEST_REF" .
        '''
      }
    }

    stage('Push Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_TOKEN')]) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail
            export DOCKER_CONFIG="$(mktemp -d)"
            trap 'docker logout >/dev/null 2>&1 || true; rm -rf "$DOCKER_CONFIG"' EXIT

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

    stage('Smoke Test') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'agent-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          sh '''#!/usr/bin/env bash
            set -euo pipefail

            ssh -i "$SSH_KEY" \
              -o IdentitiesOnly=yes \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              "${SSH_USER}@${APP_SERVER_HOST}" \
              "curl -fsS http://127.0.0.1:${APP_PORT} >/dev/null"
          '''
        }
      }
    }
  }

  post {
    always {
      sh '''#!/usr/bin/env bash
        set +e
        if [ -n "${IMAGE_REF:-}" ]; then
          docker image rm "$IMAGE_REF" >/dev/null 2>&1 || true
        fi
        if [ -n "${IMAGE_LATEST_REF:-}" ]; then
          docker image rm "$IMAGE_LATEST_REF" >/dev/null 2>&1 || true
        fi
      '''
    }
  }
}
