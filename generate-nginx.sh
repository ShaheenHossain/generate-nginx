#!/bin/bash

# Declare the domain and backend server variables
DOMAIN_NAME="domain.com" # Replace with your domain
BACKEND_SERVER="IP:port" # Replace with your backend IP and port

# Generate the Nginx configuration file
cat <<EOL > /etc/nginx/sites-available/$DOMAIN_NAME
# Upstreams
upstream backend {
    server $BACKEND_SERVER;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    # Logs
    access_log /var/log/nginx/${DOMAIN_NAME}_access.log;
    error_log /var/log/nginx/${DOMAIN_NAME}_error.log;

    # Increase client upload size
    client_max_body_size 100M;

    # Security headers
    add_header Content-Security-Policy "upgrade-insecure-requests";
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer";
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header Permissions-Policy "interest-cohort=()";

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;  
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml;

    # Location block for backend
    location / {
        proxy_set_header Connection "";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_set_header Early-Data \$ssl_early_data;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        proxy_read_timeout 600s;
        proxy_http_version 1.1;
        proxy_pass http://backend;
    }
}

# HTTP to HTTPS Redirect
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}
EOL

# Enable the site
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/$DOMAIN_NAME

# Test and reload Nginx
if nginx -t; then
    systemctl reload nginx
    echo "Nginx configuration for $DOMAIN_NAME has been successfully applied."
else
    echo "Nginx configuration test failed. Please check the configuration."
fi
