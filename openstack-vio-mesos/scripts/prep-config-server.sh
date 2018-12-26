#!/bin/bash

# Install latest stable ansible from ansible maintained ppa repository
sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update -y
sudo apt-get install -y ansible

# Create & prep workspace for ansible configs & playbooks
mkdir -p ~/ansible/inventory
touch ~/ansible/inventory/masters
touch ~/ansible/inventory/slaves
