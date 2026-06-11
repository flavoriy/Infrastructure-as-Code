#!/usr/bin/env bash
set -euo pipefail

# Installs and starts the Jenkins controller service.
# Run this on the EC2 instance created by the `jenkins_server` Terraform module.
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fontconfig openjdk-21-jre

# Add the Jenkins LTS APT repository and signing key.
sudo install -m 0755 -d /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins

# Enable Jenkins so it starts automatically after EC2 stop/start.
sudo systemctl enable --now jenkins

echo "Jenkins installed."
echo "Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || true
