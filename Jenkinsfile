// ─────────────────────────────────────────────────────────────────────────────
//  Declarative Jenkins Pipeline
//  Covers: Days 3–6 (Git → Shell Scripts → Jenkins → Docker → Terraform → AWS)
//
//  Prerequisites in Jenkins:
//    • Terraform Plugin installed  (Manage Jenkins → Plugins → Terraform)
//    • Terraform auto-installer configured  (Global Tool Config → Terraform)
//    • Credentials:
//        - AWS_ACCESS_KEY_ID     (Secret text)
//        - AWS_SECRET_ACCESS_KEY (Secret text)
//        - EC2_SSH_KEY           (SSH Username with private key, user=ec2-user)
//        - DOCKERHUB_CREDS       (Username with password)
// ─────────────────────────────────────────────────────────────────────────────

pipeline {

  agent any

  // ── Tool: Terraform Plugin auto-installer ──────────────────────────────────
  tools {
    terraform 'Terraform-1.7'   // must match the name in Global Tool Config
  }

  // ── Pipeline-level environment ─────────────────────────────────────────────
  environment {
    AWS_REGION       = 'us-east-1'
    PROJECT_NAME     = 'devops-project'
    DOCKER_IMAGE     = "your-dockerhub-username/${PROJECT_NAME}"
    DOCKER_TAG       = "${BUILD_NUMBER}"
    TF_DIR           = 'terraform'
    APP_DIR          = 'app'
    KEY_PAIR_NAME    = 'your-aws-keypair-name'   // ← change this
  }

  // ── Trigger: GitHub webhook or poll every minute ───────────────────────────
  triggers {
    githubPush()
    // pollSCM('* * * * *')   // uncomment if you prefer polling
  }

  stages {

    // ── Stage 1: Checkout ───────────────────────────────────────────────────
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/your-username/devops-project.git'
        echo "✅ Code checked out — Build #${BUILD_NUMBER}"
      }
    }

    // ── Stage 2: Shell Script Checks (Day 3) ────────────────────────────────
    stage('Pre-flight Checks') {
      steps {
        sh '''
          echo "=== Environment Check ==="
          echo "Workspace : ${WORKSPACE}"
          echo "Build     : ${BUILD_NUMBER}"
          echo "Branch    : $(git rev-parse --abbrev-ref HEAD)"
          echo "Commit    : $(git rev-parse --short HEAD)"

          echo "=== Tool Versions ==="
          terraform --version
          docker --version

          echo "=== Listing project files ==="
          ls -la
        '''
      }
    }

    // ── Stage 3: Terraform — Provision AWS Infra ────────────────────────────
    stage('Terraform: Init & Plan') {
      environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
      }
      steps {
        dir("${TF_DIR}") {
          sh '''
            echo "=== Terraform Init ==="
            terraform init

            echo "=== Terraform Validate ==="
            terraform validate

            echo "=== Terraform Plan ==="
            terraform plan \
              -var="aws_region=${AWS_REGION}" \
              -var="project_name=${PROJECT_NAME}" \
              -var="key_pair_name=${KEY_PAIR_NAME}" \
              -out=tfplan
          '''
        }
      }
    }

    stage('Terraform: Apply') {
      environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
      }
      steps {
        dir("${TF_DIR}") {
          // Pause for manual approval before applying (safe practice)
          input message: 'Apply Terraform plan to AWS?', ok: 'Apply'
          sh '''
            echo "=== Terraform Apply ==="
            terraform apply -auto-approve tfplan

            echo "=== Outputs ==="
            terraform output
          '''
          // Save EC2 IP for later stages
          script {
            env.EC2_IP = sh(
              script: "terraform output -raw ec2_public_ip",
              returnStdout: true
            ).trim()
            echo "EC2 Public IP: ${EC2_IP}"
          }
        }
      }
    }

    // ── Stage 4: Docker Build & Push (Day 6) ────────────────────────────────
    stage('Docker: Build') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            echo "=== Docker Build ==="
            docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
            docker tag  ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
            docker images | grep ${PROJECT_NAME}
          '''
        }
      }
    }

    stage('Docker: Push to DockerHub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'DOCKERHUB_CREDS',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo "=== Docker Login & Push ==="
            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
            docker push ${DOCKER_IMAGE}:latest
            docker logout
          '''
        }
      }
    }

    // ── Stage 5: Deploy to EC2 via SSH (Day 6) ──────────────────────────────
    stage('Deploy to EC2') {
      steps {
        sshagent(['EC2_SSH_KEY']) {
          sh '''
            echo "=== Deploying to EC2: ${EC2_IP} ==="

            # Wait for EC2 to be fully ready (user_data bootstrap takes ~60s)
            sleep 30

            ssh -o StrictHostKeyChecking=no ec2-user@${EC2_IP} << 'REMOTE'
              echo "--- On EC2: pulling & running container ---"

              # Pull latest image
              docker pull ${DOCKER_IMAGE}:latest

              # Stop & remove old container (if running)
              docker stop devops-app 2>/dev/null || true
              docker rm   devops-app 2>/dev/null || true

              # Run new container
              docker run -d \
                --name devops-app \
                --restart unless-stopped \
                -p 80:80 \
                ${DOCKER_IMAGE}:latest

              echo "--- Container status ---"
              docker ps -a --filter name=devops-app
REMOTE
          '''
        }
      }
    }

    // ── Stage 6: Health Check ────────────────────────────────────────────────
    stage('Health Check') {
      steps {
        sh '''
          echo "=== Waiting for app to start... ==="
          sleep 10

          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_IP})
          echo "HTTP Status: ${HTTP_STATUS}"

          if [ "${HTTP_STATUS}" = "200" ]; then
            echo "✅ App is live at http://${EC2_IP}"
          else
            echo "❌ Health check failed — status ${HTTP_STATUS}"
            exit 1
          fi
        '''
      }
    }

  } // end stages

  // ── Post actions ───────────────────────────────────────────────────────────
  post {

    success {
      echo """
        ╔═══════════════════════════════════════╗
        ║  ✅  PIPELINE SUCCEEDED               ║
        ║  App URL: http://${EC2_IP}            ║
        ║  Build  : #${BUILD_NUMBER}            ║
        ╚═══════════════════════════════════════╝
      """
    }

    failure {
      echo "❌ Pipeline FAILED at stage: ${STAGE_NAME}"

      // Optional: auto-destroy infra on failure to avoid charges
      // withCredentials([...]) {
      //   dir("${TF_DIR}") {
      //     sh 'terraform destroy -auto-approve ...'
      //   }
      // }
    }

    always {
      // Clean up local Docker images to save disk space
      sh 'docker image prune -f || true'
    }

  }

}
