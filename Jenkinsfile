pipeline {
    agent none
    environment {
        DOCKERHUB_CREDENTIALS = credentials('DockerLogin')
        SNYK_CREDENTIALS = credentials('SnykToken')
        SONARQUBE_CREDENTIALS = credentials('SonarToken')
    }
    stages {
        stage('Secret Scanning Using Trufflehog') {
            agent {
                docker {
                    image 'trufflesecurity/trufflehog:latest'
                    args '-u root --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'trufflehog filesystem . --exclude-paths trufflehog-excluded-paths.txt --fail --json > trufflehog-scan-result.json'
                }
                sh 'cat trufflehog-scan-result.json'
                archiveArtifacts artifacts: 'trufflehog-scan-result.json'
            }
        }
        stage('Build') {
            agent {
                docker {
                    image 'maven:3.9.4-eclipse-temurin-17-alpine'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn clean install'
            }
        }
        stage('SCA Snyk Test') {
            agent {
              docker {
                  image 'snyk/snyk:node'
                  args '-u root --network host --env SNYK_TOKEN=$SNYK_CREDENTIALS_PSW --entrypoint='
              }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'snyk test --json > snyk-scan-report.json'
                }
                sh 'cat snyk-scan-report.json'
                archiveArtifacts artifacts: 'snyk-scan-report.json'
            }
        }
//        stage('SCA OWASP Dependency Check') {
//            agent {
//              docker {
//                  image 'owasp/dependency-check:latest'
//                  args '-u root -v /var/run/docker.sock:/var/run/docker.sock --entrypoint='
//              }
//            }
//            steps {
//                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
//                    sh '/usr/share/dependency-check/bin/dependency-check.sh --scan . --project "NodeJS Goof" --format ALL'
//                }
//                archiveArtifacts artifacts: 'dependency-check-report.html'
//                archiveArtifacts artifacts: 'dependency-check-report.json'
//                archiveArtifacts artifacts: 'dependency-check-report.xml'
//            }
//        }
        stage('SCA Trivy Scan Dockerfile Misconfiguration') {
            agent {
              docker {
                  image 'aquasec/trivy:latest'
                  args '-u root --network host --entrypoint='
              }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'trivy config Dockerfile --exit-code=1 --format json > trivy-scan-dockerfile-report.json'
                }
                sh 'cat trivy-scan-dockerfile-report.json'
                archiveArtifacts artifacts: 'trivy-scan-dockerfile-report.json'
            }
        }
        stage('SAST Snyk') {
            agent {
              docker {
                  image 'snyk/snyk:node'
                  args '-u root --network host --env SNYK_TOKEN=$SNYK_CREDENTIALS_PSW --entrypoint='
              }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'snyk code test --json > snyk-sast-report.json'
                }
                sh 'cat snyk-scan-report.json'
                archiveArtifacts artifacts: 'snyk-sast-report.json'
            }
        }
        stage('SAST SonarQube') {
            agent {
              docker {
                    image 'maven:3.9.4-eclipse-temurin-17-alpine'
                    args '-u root --network host'
              }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'mvn sonar:sonar -Dsonar.token=$SONARQUBE_CREDENTIALS_PSW -Dsonar.projectKey=javulna -Dsonar.qualitygate.wait=true -Dsonar.host.url=http://localhost:9000' 
                }
            }
        }
        stage('Build Docker Image and Push to Docker Registry') {
            agent {
                docker {
                    image 'docker:dind'
                    args '--user root --network host -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
                sh 'docker build -t xenjutsu/javulna:0.1 .'
                sh 'docker push xenjutsu/javulna:0.1'
            }
        }
        stage('Deploy Docker Image') {
            agent {
                docker {
                    image 'kroniak/ssh-client'
                    args '--user root --network host'
                }
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "DeploymentSSHKey", keyFileVariable: 'keyfile')]) {
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no root@119.81.54.27 "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no root@119.81.54.27 docker pull xenjutsu/javulna:0.1'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no root@119.81.54.27 docker rm --force javulna'
                    sh 'ssh -i ${keyfile} -o StrictHostKeyChecking=no root@119.81.54.27 docker run -it --detach -p 8090:8090 --name javulna xenjutsu/javulna:0.1'
                }
            }
        }
        stage('DAST Nuclei') {
            agent {
                docker {
                    image 'projectdiscovery/nuclei'
                    args '--user root --network host --entrypoint='
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'nuclei -u http://192.168.0.110:8090 -nc -j > nuclei-report.json'
                    sh 'cat nuclei-report.json'
                }
                archiveArtifacts artifacts: 'nuclei-report.json'
            }
        }
        stage('DAST OWASP ZAP') {
            agent {
                docker {
                    image 'ghcr.io/zaproxy/zaproxy:weekly'
                    args '-u root --network host -v /var/run/docker.sock:/var/run/docker.sock --entrypoint= -v .:/zap/wrk/:rw'
                }
            }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'zap-api-scan.py -t doc/javulna.yaml -f openapi -r zapapiscan.html -x zapapiscan.xml'
                }
                sh 'cp /zap/wrk/zapbaseline.html ./zapapiscan.html'
                sh 'cp /zap/wrk/zapbaseline.xml ./zapapiscan.xml'
                archiveArtifacts artifacts: 'zapapiscan.html'
                archiveArtifacts artifacts: 'zapapiscan.xml'
            }
        }
    }
}
