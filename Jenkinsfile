pipeline {

    agent any

    environment {
        KUBECONFIG = credentials('minikube-kubeconfig')
    }

    stages {

        // Give Permissions to the Necessary Scripts
        stage('Permissions') {
            steps {
                script {
                    sh 'chmod +x ./kubernetes_rollout.sh'
                    sh 'chmod +x ./tools/build_docker.sh'
                    sh 'chmod +x ./tools/build_demo_server.sh'
                    sh 'chmod +x ./examples/live-demo/images/load_minikube.sh'
                }
            }
        }

        // Build the TeaStore (Must allow Jenkins to run on sudo permission)
        stage('Run Maven') {
            steps {
                script {
                    sh 'sudo mvn clean install -Dskiptests -e'
                }
            }
        }

        // Build Docker Files (TeaStore and Demo Server) and Store them as .tar
        stage('Build Docker') {
            steps {
                script {
                    sh '''
                        (
                          cd ./tools
                          build_docker.sh
                          build_demo_server.sh
                        )
                    '''
                }
            }
        }
        // By now, Docker images are in examples/live-demo/images
        stage('Load Images to Kubernetes Cluster') {
            steps {
                script {
                    sh '''
                        (
                          cd ./examples/live-demo/images
                          load_minikube.sh
                        )
                    '''
                }
            }
        }
        // Deploy Containers to Kubernetes Cluster
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Deploy using kubectl
                    sh '''
                        (
                          cd ./examples/live-demo/kubernetes
                          kubectl apply -f teastore-rabbitmq_v16.yaml

                          // Wait for RabbitMQ to be initialize fully
                          sleep 20 

                          kubectl apply -f teastore-ribbon-kieker_v16.yaml
                          kubectl apply -f teastore-demo-server.yaml
                        )
                    '''
                }
            }
        }
        // Update Containers
        stage('Rollout Restart') {
            steps {
                script {
                    sh './kubernetes_rollout.sh'
                }
            }
        }
    }
}

