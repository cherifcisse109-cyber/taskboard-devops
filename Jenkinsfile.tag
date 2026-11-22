// Pipeline 3 : Build versionne sur tag vX.Y.Z avec archivage d'artefacts
// Job Jenkins : Multibranch Pipeline avec le comportement "Discover tags"
// Script Path : Jenkinsfile.tag

def NODE_VERSIONS = ['18', '20', '22']    // build parallele par version de runtime
def SAFE_TAG      = { env.BUILD_TAG.replaceAll('[^a-zA-Z0-9_.-]', '_') }

pipeline {
  agent any
  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '30'))
  }
  parameters {
    booleanParam(name: 'FORCE_SMOKE_FAIL', defaultValue: false,
                 description: 'Demo : force un echec du smoke test')
  }

  stages {
    stage('Build versionne (tag)') {
      when { tag pattern: 'v\\d+\\.\\d+\\.\\d+', comparator: 'REGEXP' }   // uniquement vX.Y.Z
      environment {
        VERSION = "${env.TAG_NAME.substring(1)}"   // v1.2.3 -> 1.2.3
      }
      stages {

        stage('Checkout') {
          steps {
            checkout scm
            sh 'rm -rf artifacts && mkdir -p artifacts/logs artifacts/images'
          }
        }

        stage('Setup') {
          steps {
            sh '''#!/bin/bash
              set -e
              docker --version
              chmod +x scripts/smoke.sh
              PKG_VERSION=$(grep -m1 '"version"' app/package.json | sed -E 's/.*"([0-9]+\\.[0-9]+\\.[0-9]+)".*/\\1/')
              echo "Tag = $TAG_NAME | package.json = $PKG_VERSION"
              if [ "$PKG_VERSION" != "$VERSION" ]; then
                echo "ERREUR : la version de package.json ($PKG_VERSION) ne correspond pas au tag ($VERSION)"
                exit 1
              fi
            '''
          }
        }

        stage('Build') {
          steps {
            script {
              parallel NODE_VERSIONS.collectEntries { v ->
                ["Build Node ${v}": {
                  sh """#!/bin/bash
                    set -o pipefail
                    docker build --build-arg NODE_VERSION=${v} --build-arg APP_VERSION=${env.VERSION} \\
                      -t taskboard:${env.VERSION}-node${v} app 2>&1 | tee artifacts/logs/build-node${v}.log
                  """
                }]
              }
            }
          }
        }

        stage('Run (Docker)') {
          steps {
            script {
              parallel NODE_VERSIONS.collectEntries { v ->
                ["Run Node ${v}": {
                  sh """
                    docker run -d --name tb-${SAFE_TAG()}-n${v} --label ci=${SAFE_TAG()} \\
                      -p ${3000 + v.toInteger()}:3000 taskboard:${env.VERSION}-node${v}
                  """
                }]
              }
            }
          }
        }

        stage('Smoke Test') {
          steps {
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
              script {
                def force = params.FORCE_SMOKE_FAIL ? '1' : '0'
                parallel NODE_VERSIONS.collectEntries { v ->
                  ["Smoke Node ${v}": {
                    sh "SMOKE_FORCE_FAIL=${force} ./scripts/smoke.sh http://${env.SMOKE_HOST ?: 'localhost'}:${3000 + v.toInteger()} artifacts/smoke-node${v}.txt"
                  }]
                }
              }
            }
          }
        }

        stage('Archive Artifacts') {
          steps {
            sh """#!/bin/bash
              # Export des images versionnees (artefacts de release)
              for v in ${NODE_VERSIONS.join(' ')}; do
                docker save taskboard:${env.VERSION}-node\$v | gzip > artifacts/images/taskboard-${env.VERSION}-node\$v.tar.gz
              done
              for c in \$(docker ps -aq --filter label=ci=${SAFE_TAG()}); do
                docker logs \$c > artifacts/logs/container-\$(docker inspect -f '{{.Name}}' \$c | tr -d /).log 2>&1 || true
              done
              (cd artifacts/images && sha256sum *.tar.gz > SHA256SUMS.txt)
              {
                echo "Pipeline      : Build versionne (tag)"
                echo "Job / Build   : ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                echo "Tag / Version : ${env.TAG_NAME} / ${env.VERSION}"
                echo "Date          : \$(date -u +%FT%TZ)"
                echo "--- Resultats smoke ---"
                grep -H RESULT artifacts/smoke-node*.txt || echo "aucun resultat smoke"
              } > artifacts/pipeline-report.txt
            """
            archiveArtifacts artifacts: 'artifacts/**', fingerprint: true, allowEmptyArchive: true
          }
        }
      }
    }
  }

  post {
    always {   // Cleanup
      sh """
        docker ps -aq --filter label=ci=${SAFE_TAG()} | xargs -r docker rm -f || true
        docker images -q 'taskboard:*-node*' --filter 'reference=taskboard:${env.TAG_NAME ? env.TAG_NAME.substring(1) : 'x'}-*' | xargs -r docker rmi -f || true
      """
    }
    success { echo "TAG ${env.TAG_NAME} : BUILD VERSIONNE PASSED" }
    failure { echo "TAG ${env.TAG_NAME} : BUILD VERSIONNE FAILED" }
  }
}
