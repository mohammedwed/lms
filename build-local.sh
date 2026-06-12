#!/bin/bash
set -e

echo "Starting local Docker build for Frappe LMS..."

# Clone frappe_docker into a temporary directory if it doesn't exist
if [ ! -d "frappe_docker" ]; then
    git clone https://github.com/frappe/frappe_docker.git
fi

# Write apps.json as a file (required for BuildKit secret mount)
APPS_JSON_FILE=$(mktemp)
cat > "$APPS_JSON_FILE" <<EOF
[
    {"url": "https://github.com/frappe/payments", "branch": "version-15"},
    {"url": "https://github.com/mohammedwed/lms", "branch": "feature/veraxity-branding"}
]
EOF

echo "Building Docker image..."
DOCKER_BUILDKIT=1 docker build \
  --no-cache \
  --secret id=apps_json,src="$APPS_JSON_FILE" \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=ghcr.io/mohammedwed/lms:stable \
  --file=frappe_docker/images/layered/Containerfile \
  frappe_docker

rm -f "$APPS_JSON_FILE"

echo ""
echo "✅ Build complete!"
echo "To push this image to GitHub Container Registry, run:"
echo "1. docker login ghcr.io -u mohammedwed"
echo "   (Use a GitHub Personal Access Token as the password)"
echo "2. docker push ghcr.io/mohammedwed/lms:stable"
