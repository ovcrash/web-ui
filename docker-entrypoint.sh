#!/bin/bash

environment=${1:-"production"}

# Configure the app's config.json with the API endpoint
# In production with reverse proxy, the API is served from the same origin
function update_app_config {
  app_cfg_base="$1"
  
  # For reverse proxy setup, the frontend accesses API via same origin
  # HASHTOPOLIS_BACKEND_URL should be the external URL (what the browser sees)
  # HASHTOPOLIS_BACKEND_URL_INTERNAL is used by nginx to proxy to the actual backend
  
  if [ -n "$HASHTOPOLIS_BACKEND_URL" ]; then
    echo "Using HASHTOPOLIS_BACKEND_URL: $HASHTOPOLIS_BACKEND_URL"
    envsubst '${HASHTOPOLIS_BACKEND_URL}' < ${app_cfg_base}/assets/config.json.example > ${app_cfg_base}/assets/config.json
  fi

  echo "Done configuring up Hashtopolis frontend (env=$environment) at $app_cfg_base/assets/config.json"
}

# Configure nginx reverse proxy to backend
function update_nginx_config {
  if [ -n "$HASHTOPOLIS_BACKEND_URL_INTERNAL" ]; then
    echo "Configuring nginx reverse proxy to: $HASHTOPOLIS_BACKEND_URL_INTERNAL"
    envsubst '${HASHTOPOLIS_BACKEND_URL_INTERNAL}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf
  else
    echo "WARNING: HASHTOPOLIS_BACKEND_URL_INTERNAL not set, reverse proxy disabled"
    # Remove template and use basic config
    rm -f /etc/nginx/conf.d/default.conf.template
  fi
}

if [ "$environment" = "development" ]; then
  # Ensure workspace is mounted
  echo -n "Waiting for workspace to be mounted..."
  until [ -f /app/package.json ]
  do
        sleep 5
  done
  echo "DONE"

  # Install/Update required Node.js packages
  export PUPPETEER_SKIP_DOWNLOAD='true'
  npm install

  # Prepare configuration
  update_app_config "/app/src"

  # Start worker instance
  echo "Starting worker npm..."
  npm start
else
  # Prepare configuration
  update_app_config "/usr/share/nginx/html"
  update_nginx_config

  # Start worker instance
  echo "Starting worker nginx..."
  nginx -g 'daemon off;'
fi