pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        APP_NAME  = 'nexvion-week12'
        IMAGE_NAME = 'nexvion-web'
        HOST_PORT = '8082'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo 'Nexvion source code checked out.'
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    set -eu

                    for file in \
                        index.html \
                        products.html \
                        payment.html \
                        style.css \
                        products.css \
                        payment.css \
                        script.js \
                        payment.js \
                        logo.png \
                        Dockerfile
                    do
                        test -f "$file" || {
                            echo "ERROR: Missing required file: $file"
                            exit 1
                        }
                    done

                    echo "All required Nexvion files are present."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    set -eu

                    docker build \
                        --pull \
                        -t "${IMAGE_NAME}:build-${BUILD_NUMBER}" .

                    echo "Docker image built successfully."
                '''
            }
        }

        stage('Test Container') {
            steps {
                sh '''
                    set -eu

                    TEST_CONTAINER="nexvion-test-${BUILD_NUMBER}"

                    cleanup() {
                        docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
                    }

                    trap cleanup EXIT

                    docker run -d \
                        --name "$TEST_CONTAINER" \
                        -p 127.0.0.1::80 \
                        "${IMAGE_NAME}:build-${BUILD_NUMBER}"

                    PORT=$(docker port "$TEST_CONTAINER" 80/tcp \
                        | head -n 1 \
                        | awk -F: '{print $NF}')

                    if [ -z "$PORT" ]; then
                        echo "ERROR: Could not determine test port."
                        exit 1
                    fi

                    for attempt in $(seq 1 15); do
                        if curl --fail --silent \
                            "http://127.0.0.1:${PORT}/" \
                            -o /dev/null; then
                            echo "Nexvion homepage returned HTTP success."
                            exit 0
                        fi

                        sleep 2
                    done

                    echo "ERROR: Nexvion homepage failed its HTTP test."
                    exit 1
                '''
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    set -eu

                    if ! command -v trivy >/dev/null 2>&1; then
                        echo "ERROR: Trivy is not available to Jenkins."
                        echo "Install Trivy before running the security gate."
                        exit 1
                    fi

                    trivy image \
                        --cache-dir /var/lib/jenkins/.cache/trivy \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        "${IMAGE_NAME}:build-${BUILD_NUMBER}"
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -eu

                    NEW_IMAGE="${IMAGE_NAME}:build-${BUILD_NUMBER}"
                    BACKUP="${APP_NAME}-previous-${BUILD_NUMBER}"
                    BACKUP_CREATED=0
                    NEW_STARTED=0

                    rollback() {
                        echo "Deployment failed. Attempting rollback."

                        if [ "$NEW_STARTED" -eq 1 ]; then
                            docker rm -f "$APP_NAME" || true
                        fi

                        if [ "$BACKUP_CREATED" -eq 1 ]; then
                            docker rename "$BACKUP" "$APP_NAME" || true
                            docker start "$APP_NAME" || true
                        fi
                    }

                    if docker inspect "$APP_NAME" >/dev/null 2>&1; then
                        docker stop "$APP_NAME"
                        docker rename "$APP_NAME" "$BACKUP"
                        BACKUP_CREATED=1
                    fi

                    if ! docker run -d \
                        --name "$APP_NAME" \
                        --restart unless-stopped \
                        -p "${HOST_PORT}:80" \
                        "$NEW_IMAGE"; then
                        rollback
                        exit 1
                    fi

                    NEW_STARTED=1

                    HEALTHY=0

                    for attempt in $(seq 1 30); do
                        STATUS=$(docker inspect \
                            --format '{{.State.Health.Status}}' \
                            "$APP_NAME" 2>/dev/null || echo unknown)

                        if [ "$STATUS" = "healthy" ] && \
                            curl --fail --silent \
                            "http://127.0.0.1:${HOST_PORT}/" \
                            -o /dev/null; then
                            HEALTHY=1
                            break
                        fi

                        sleep 2
                    done

                    if [ "$HEALTHY" -ne 1 ]; then
                        echo "ERROR: Deployment health check failed."
                        docker logs "$APP_NAME" || true
                        rollback
                        exit 1
                    fi

                    if [ "$BACKUP_CREATED" -eq 1 ]; then
                        docker rm "$BACKUP"
                    fi

                    echo "Nexvion deployment is healthy."
                    echo "Website: http://localhost:${HOST_PORT}"
                '''
            }
        }
    }

    post {
        success {
            echo 'Nexvion CI/CD pipeline completed successfully.'
        }

        failure {
            echo 'Nexvion CI/CD pipeline failed. Review the stage logs.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}
