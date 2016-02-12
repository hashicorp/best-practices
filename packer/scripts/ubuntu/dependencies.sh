#!/bin/bash
set -e

echo Install dependencies...
# Update the box
apt-get -y update
apt-get -y upgrade

# Install dependencies
apt-get -y install curl unzip jq
