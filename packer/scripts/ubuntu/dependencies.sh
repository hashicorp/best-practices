#!/bin/bash
set -e

echo Install dependencies...
# Update the box
apt-get -qqy update
apt-get -qqy upgrade

# Install dependencies
apt-get -qqy install curl unzip jq
