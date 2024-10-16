# **JENKINS CRITITHINKING PROJECT**

# _Objective:_ This project requires setting up a comprehensive Jenkins pipeline for a web application, managing everything from building the app to deploying it into production, while handling challenges like dependency management, environment configuration, security, and rollback strategies.

# Jenkins Pipeline for Node.js Application

## step by step walk through;

# Step 1: Design the Pipeline

The pipeline should consist of the following stages:

- Build: Compile the application.
- Test: Run unit tests.
- Package: Create a deployable artifact (e.g., Docker image).
- Deploy to Staging: Deploy the application to a staging environment.
- Approval: Wait for manual approval.
- Deploy to Production: Deploy the application to production.

Tools & Technologies that can be used :

- Jenkins for CI/CD.
- Maven/Gradle/NPM (depending on your application) for building.
- JUnit/Mocha/Jest for testing.
- Docker for packaging.
- Ansible/Kubernetes/AWS (or others) for deployment.

# Step 2: Implementing the Pipeline in Jenkins

Defining the pipeline using either the Jenkinsfile (pipeline as code). Defining elements of the jenkinsfile.

```groovy
pipeline {
    agent any
```

- pipeline: The pipeline block is the top-level block that defines the entire Jenkins pipeline.
- agent any: agent any means the pipeline can run on any available Jenkins agent

```groovy
    environment {
        NODE_ENV = 'development'
        DOCKER_IMAGE = "my-tee-app:${BUILD_NUMBER}"
        REGISTRY_CREDENTIALS = credentialsREGISTRY_CREDENTIALS = credentials('docker-registry-credentials')  // Fetch credentials
    }
```

environment: The environment block defines the environment variables that can be accessed by the pipeline.

- NODE_ENV = 'development': Specifies the environment in which the app will run (development, staging, or production).
- DOCKER_IMAGE: Defines a Docker image name, appending the Jenkins build number (${BUILD_NUMBER}) to tag each Docker image uniquely.
- REGISTRY_CREDENTIALS: Sets the Docker registry URL where the image will be pushed.

# **Error handling**

- **try-catch block: Added to different stages to catch errors during the pipeline execution. If an error occurs, the build will fail, and appropriate actions (such as rollback) will be triggered.**

- Custom error messages: Each catch block provides a specific error message indicating which part of the pipeline failed (e.g., failed unit tests, failed Docker push).

- Abort build: In each catch block, the build is marked as failed using currentBuild.result = 'FAILURE', and the error function is called to stop the pipeline execution.

```groovy
try {
    sh 'mvn deploy'
} catch (Exception e) {
    echo "Deployment failed"
    currentBuild.result = 'FAILURE' // Mark the build as failed
                        error "Aborting build due to failed dependency installation."
}
```

# **Stages Block**

The stages block contains all the different stages of the pipeline. Each stage represents a step in the pipeline, such as building, testing, or deploying the application.

```groovy
    stages('Build') {

        stage('Install Dependencies') {
            steps {
                script {
                    echo 'Installing dependencies...'
                }
                // Use caching to speed up npm install
                cache(path: 'node_modules', key: 'npm-cache-${BUILD_NUMBER}', fallback: true) {
                    sh 'npm install'
                }
            }
        }
```

- _Install Dependencies:_ This stage installs the necessary Node.js dependencies using npm install.
  - cache(path: 'node_modules', key: 'npm-cache-${BUILD_NUMBER}', fallback: true): Caches the node_modules folder, so future builds will not need to reinstall packages if the cache is still valid. This speeds up the pipeline.
  - sh 'npm install': Runs the command in the Jenkins environment to install the Node.js packages defined in package.json.
- **Scalability**

```groovy
        stage('Run Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            echo 'Running unit tests...'
                        }
                        sh 'npm test'
                    }
                }
                stage('Linting') {
                    steps {
                        script {
                            echo 'Running code linting...'
                        }
                        sh 'npm run lint'
                    }
                }
            }
        }
```

- _Run Tests:_ The parallel directive allows you to run multiple stages at the same time. It is useful for running different test suites or builds concurrently.

**Build and Package** This stage builds the Docker image for the Node.js application and pushes it to a Docker registry.

```groovy
        stage('Build and Package') {
            steps {
                script {
                    echo 'Building Docker image...'
                    sh 'docker build -t ${DOCKER_IMAGE} .'
                }
                script {
                    echo 'Pushing Docker image to registry...'
                    sh "docker tag ${DOCKER_IMAGE} ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                    sh "docker push ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                }
            }
        }
```

**Deploy to Staging:** Deploys the application to a staging environment for testing prototype.

```groovy
        stage('Deploy to Staging') {
            environment {
                NODE_ENV = 'staging'
            }
            steps {
                script {
                    echo 'Deploying to staging...'
                    sh "docker run -d -e NODE_ENV=staging -p 3000:3000 ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                }
            }
        }
```

- The NODE_ENV is set to staging to ensure the correct environment-specific configuration is used.
- docker run -d -e NODE_ENV=staging -p 3000:3000 ${DOCKER_REGISTRY}:${BUILD_NUMBER}: Runs the Docker container in the background (-d) with the NODE_ENV=staging environment variable. It exposes the application on port 3000.

**Approval:** This stage waits for manual approval before deploying to production

```groovy
        stage('Approval') {
            steps {
                input message: 'Approve deployment to production?', ok: 'Deploy'
            }
        }
```

- input message: 'Approve deployment to production?', ok: 'Deploy': Presents a prompt to the stakeholder

**Deploy to Production:** After approval, this stage deploys the application to the production environment.

```groovy
 stage('Deploy to Production') {
            environment {
                NODE_ENV = 'production'
            }
            steps {
                script {
                    try {
                        echo 'Deploying to production...'
                        sh "docker run -d -e NODE_ENV=production -p 80:3000 ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                    } catch (err) {
                        echo 'Failed to deploy to production!'
                        currentBuild.result = 'FAILURE'
                        error "Aborting build due to failed production deployment."
                    }
                }
            }
```

- docker run -d -e NODE_ENV=production -p 80:3000 ${DOCKER_REGISTRY}:${BUILD_NUMBER}: Runs the Docker container in production, exposing it on port 80 (standard HTTP port).

# **Post-build Actions**

```groovy
post {
    success {
        echo 'Build and deployment succeeded!'
        // Send email notification for success
        mail to: 'your-email@example.com',
             subject: "SUCCESS: Build #${BUILD_NUMBER} was successful!",
             body: """The Jenkins build and deployment succeeded.

                     Project: ${JOB_NAME}
                     Build Number: ${BUILD_NUMBER}
                     Build URL: ${BUILD_URL}

                     Please check the application in production.
                  """
    }

    failure {
        echo 'Build failed!'
        // Send email notification for failure
        mail to: 'your-email@example.com',
             subject: "FAILED: Build #${BUILD_NUMBER} failed!",
             body: """The Jenkins build failed.

                     Project: ${JOB_NAME}
                     Build Number: ${BUILD_NUMBER}
                     Build URL: ${BUILD_URL}

                     Please investigate the issue.
                  """
    }

    always {
        // Cleanup Docker images or other tasks
        script {
            echo 'Cleaning up Docker images...'
            sh 'docker system prune -f'
        }
    }
}
```

**post:** Defines actions that happen after the pipeline completes.

- success: If the pipeline succeeds:
  echo 'Build and deployment succeeded!': Outputs a success message.
- failure: If the pipeline fails:
  echo 'Build failed!': Outputs a failure message.
- Rollback strategy: In case of a failure, the failure post block will attempt to rollback the deployment to the previous stable version.

```groovy
        always {
            script {
                echo 'Cleaning up Docker images...'
                sh 'docker system prune -f'
            }
        }
    }
}
```

**always:** This block ensures that certain actions happen whether the build succeeds or fails.
docker system prune -f: Cleans up unused Docker images and containers to save disk space.
