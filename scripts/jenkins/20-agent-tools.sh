#!/usr/bin/env bash
set -euo pipefail

# Installs CI tools used by Jenkins pipelines on the build agent.
# Run after common/00-base.sh and common/10-docker.sh.
SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-7.2.0.5079}"

# Java is required by Sonar Scanner and many Jenkins build steps.
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jre unzip

# Install Node.js 22 from NodeSource for JavaScript/TypeScript builds.
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Install Trivy from Aqua's APT repository for container/dependency scanning.
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y trivy

# Install Sonar Scanner CLI under /opt and expose it through /usr/local/bin.
cd /tmp
curl -fsSLo sonar-scanner.zip \
  "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip"
sudo rm -rf "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64" /opt/sonar-scanner
sudo unzip -q sonar-scanner.zip -d /opt
sudo ln -s "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64" /opt/sonar-scanner
sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

# Jenkins SSH agents commonly use this path as their remote root directory.
mkdir -p /home/ubuntu/jenkins-agent
sudo chown -R ubuntu:ubuntu /home/ubuntu/jenkins-agent

# Print versions so the operator can verify the agent toolchain immediately.
java -version
node --version
npm --version
trivy --version
sonar-scanner --version

echo "Jenkins agent tools installed."
