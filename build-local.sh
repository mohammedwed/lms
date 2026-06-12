#!/bin/bash
set -e

echo "Starting local Docker build for Frappe LMS..."

# Clone frappe_docker into a temporary directory if it doesn't exist
if [ ! -d "frappe_docker" ]; then
    git clone https://github.com/frappe/frappe_docker.git
fi

# Define the apps we want to include in the image
APPS_JSON='[
    {"url": "https://github.com/frappe/payments","branch": "version-15"},
    {"url": "https://github.com/mohammedwed/lms","branch": "feature/veraxity-branding"}
]'
APPS_JSON_BASE64=$(echo ${APPS_JSON} | base64 -w 0)

echo "Building Docker image..."
docker build \
  --no-cache \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64=${APPS_JSON_BASE64} \
  --tag=ghcr.io/mohammedwed/lms:stable \
  --file=frappe_docker/images/layered/Containerfile \
  frappe_docker

echo ""
echo "✅ Build complete!"
echo "To push this image to GitHub Container Registry, run:"
echo "1. docker login ghcr.io -u mohammedwed"
echo "   (Use a GitHub Personal Access Token as the password)"
echo "2. docker push ghcr.io/mohammedwed/lms:stable"
