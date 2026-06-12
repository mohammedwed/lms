#!/bin/bash
set -e

echo "Deploying Frappe LMS Production Stack..."

if [ ! -f .env ]; then
  echo "Error: .env file not found. Please copy .env.example to .env and configure it."
  exit 1
fi

source .env

echo "Pulling latest image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker compose pull

echo "Starting configurator (sets up apps.txt and common_site_config.json)..."
docker compose up -d configurator
docker compose wait configurator

echo "Starting MariaDB and Redis..."
docker compose up -d mariadb redis-cache redis-queue

echo "Waiting for database to be ready..."
sleep 15

echo "Creating or updating site..."
# We run create-site which executes bench new-site.
# If it fails (site exists), we just continue.
docker compose up -d create-site || true
docker compose wait create-site || true

echo "Starting backend and frontend..."
docker compose up -d backend frontend websocket

echo "Starting workers and scheduler..."
docker compose up -d queue-default queue-short queue-long scheduler

echo "Running migrations..."
docker compose exec backend bench --site ${SITE_NAME} migrate

echo "Deployment completed successfully!"
echo "Access the frontend at http://localhost:8080"
echo "Make sure to configure a reverse proxy (like Nginx, Caddy, or Traefik) to expose port 8080 to the web."
