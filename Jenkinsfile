pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: 'CHANGE_ME', description: 'DockerHub namespace or organization')
    }

    environment {
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-jenkins-exam'
        KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-exam'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim()
                    env.IMAGE_NAMESPACE = params.DOCKERHUB_NAMESPACE.trim()
                    if (!env.IMAGE_NAMESPACE || env.IMAGE_NAMESPACE == 'CHANGE_ME') {
                        error('Set the DOCKERHUB_NAMESPACE build parameter before pushing images')
                    }
                    env.IMAGE_MOVIE_REPOSITORY = "${env.IMAGE_NAMESPACE}/jenkins-exam-movie-service"
                    env.IMAGE_CAST_REPOSITORY = "${env.IMAGE_NAMESPACE}/jenkins-exam-cast-service"
                }
            }
        }

        stage('Validate and Test') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    docker compose -p jenkins-exam-ci config --quiet
                    docker compose -p jenkins-exam-ci up -d --build --wait --wait-timeout 180
                    trap 'docker compose -p jenkins-exam-ci down' EXIT
                    python3 tests/smoke.py
                    docker compose -p jenkins-exam-ci exec -T movie_service python -m pip check
                    docker compose -p jenkins-exam-ci exec -T cast_service python -m pip check
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    docker build -t "$IMAGE_MOVIE_REPOSITORY:$IMAGE_TAG" movie-service
                    docker build -t "$IMAGE_CAST_REPOSITORY:$IMAGE_TAG" cast-service
                '''
            }
        }

        stage('Push Images') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIALS_ID,
                    usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                    sh '''#!/bin/sh
                        set -eu
                        printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USER" --password-stdin
                        docker push "$IMAGE_MOVIE_REPOSITORY:$IMAGE_TAG"
                        docker push "$IMAGE_CAST_REPOSITORY:$IMAGE_TAG"
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy Dev') {
            when { branch 'dev' }
            steps { script { deployExamEnvironment('dev') } }
        }

        stage('Deploy QA') {
            when { branch 'qa' }
            steps { script { deployExamEnvironment('qa') } }
        }

        stage('Deploy Staging') {
            when { branch 'staging' }
            steps { script { deployExamEnvironment('staging') } }
        }

        stage('Approve Production') {
            when { branch 'master' }
            steps {
                input message: 'Deploy this tested image to production?', ok: 'Deploy production'
            }
        }

        stage('Deploy Prod') {
            when { branch 'master' }
            steps { script { deployExamEnvironment('prod') } }
        }
    }
}

def deployExamEnvironment(String environment) {
    withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
        sh """#!/bin/sh
            set -eu
            namespace="jenkins-exam-${environment}"
            release="exam-${environment}"
            helm upgrade --install "\$release" charts \\
                --namespace "\$namespace" \\
                --create-namespace=false \\
                --set-string environment="${environment}" \\
                --set-string services.movie.repository="\$IMAGE_MOVIE_REPOSITORY" \\
                --set-string services.movie.tag="\$IMAGE_TAG" \\
                --set-string services.cast.repository="\$IMAGE_CAST_REPOSITORY" \\
                --set-string services.cast.tag="\$IMAGE_TAG" \\
                --wait --timeout 10m
            kubectl rollout status --namespace "\$namespace" deployment/"\$release-fastapiapp-movie" --timeout=5m
            kubectl rollout status --namespace "\$namespace" deployment/"\$release-fastapiapp-cast" --timeout=5m
            kubectl get pods,services,statefulsets --namespace "\$namespace" -l app.kubernetes.io/instance="\$release"
        """
    }
}
