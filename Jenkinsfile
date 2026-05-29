pipeline {
  agent { label 'worker' }

  parameters {
    string(name: 'APP_SERVER_HOST', defaultValue: '', description: 'Private IP or DNS name of the app server')
  }

  environment {
    IMAGE_NAME = 'capstone-nginx'
    IMAGE_TAG = 'latest'
    CONTAINER_NAME = 'capstone-nginx'
    APP_PORT = '8081'
    DEPLOY_DIR = '/opt/capstone-app'
  }

  stages {
    stage('Validate') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euo pipefail
          test -n "$APP_SERVER_HOST"
          test -f app/index.html
          test -f Dockerfile
          test -f scripts/deploy_app.sh
        '''
      }
    }

    stage('Build Image') {
      steps {
        sh 'docker build -t "$IMAGE_NAME:$IMAGE_TAG" .'
      }
    }

    stage('Deploy') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'agent-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
          sh 'bash scripts/deploy_app.sh'
        }
      }
    }
  }
}
