freeStyleJob('test-agent') {
  description('Quick test job to verify agent + docker + java.')
  label('worker')   // matches labelString "linux docker worker" (contains "worker")
  logRotator { numToKeep(25) }

  steps {
    shell('''#!/usr/bin/env bash
set -euxo pipefail

echo "=== whoami ==="
whoami

echo "=== hostname ==="
hostname

echo "=== java ==="
java -version || true

echo "=== docker ==="
docker --version || true
docker ps || true
''')
  }
}
