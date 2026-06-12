#!/bin/bash
set -e

echo "Starting local Docker build for Frappe LMS..."

# Clone frappe_docker into a temporary directory if it doesn't exist
if [ ! -d "frappe_docker" ]; then
    git clone https://github.com/frappe/frappe_docker.git
fi

# Write apps.json directly into the build context root
cat > frappe_docker/apps.json <<EOF
[
    {"url": "https://github.com/frappe/payments", "branch": "version-16"},
    {"url": "https://github.com/mohammedwed/lms", "branch": "feature/veraxity-branding"}
]
EOF

# Patch the Containerfile to use COPY instead of secret mounting
sed -i 's/RUN --mount=type=secret,id=apps_json,target=\/opt\/frappe\/apps.json,uid=1000,gid=1000 \\/COPY apps.json \/opt\/frappe\/apps.json\nRUN \\/g' frappe_docker/images/layered/Containerfile

echo "Building Docker image..."
docker buildx build \
  --no-cache \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-16 \
  --tag=ghcr.io/mohammedwed/lms:stable \
  --file=frappe_docker/images/layered/Containerfile \
  --load \
  frappe_docker

echo ""
echo "✅ Build complete!"
echo "To push this image to GitHub Container Registry, run:"
echo "1. docker login ghcr.io -u mohammedwed"
echo "   (Use a GitHub Personal Access Token as the password)"
echo "2. docker push ghcr.io/mohammedwed/lms:stable"
