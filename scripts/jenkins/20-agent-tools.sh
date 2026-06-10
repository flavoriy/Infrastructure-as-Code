#!/usr/bin/env bash
set -euo pipefail

SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-7.2.0.5079}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jre unzip

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

sudo install -m 0755 -d /etc/apt/keyrings
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y trivy

cd /tmp
curl -fsSLo sonar-scanner.zip \
  "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip"
sudo rm -rf "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64" /opt/sonar-scanner
sudo unzip -q sonar-scanner.zip -d /opt
sudo ln -s "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64" /opt/sonar-scanner
sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

mkdir -p /home/ubuntu/jenkins-agent
sudo chown -R ubuntu:ubuntu /home/ubuntu/jenkins-agent

java -version
node --version
npm --version
trivy --version
sonar-scanner --version

echo "Jenkins agent tools installed."

