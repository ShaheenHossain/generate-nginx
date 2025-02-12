#!/bin/bash

# Declare the domain and backend server variables
DOMAIN_NAME="sub.domain.com"
BACKEND_SERVER="IP:PORT"

# Extract a unique upstream name from the domain (e.g., replace dots with underscores)
# UPSTREAM_NAME=$(echo "$DOMAIN_NAME" | tr '.' '_')_backend

UPSTREAM_NAME=$(echo "$DOMAIN_NAME" | tr '.' '_')_backend_$(date +%s)

# Generate the Nginx configuration file
cat <<EOL > /etc/nginx/sites-available/$DOMAIN_NAME
# Upstreams
upstream $UPSTREAM_NAME {
    server $BACKEND_SERVER;  # No 'http://' prefix
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    # Logs
    access_log /var/log/nginx/${DOMAIN_NAME}_access.log;
    error_log /var/log/nginx/${DOMAIN_NAME}_error.log;

    # Increase client upload size
    client_max_body_size 500M;

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
    ssl_protocols TLSv1.2 TLSv1.3;  # Remove duplicates

    #ssl_certificate /etc/nginx/certificate/$DOMAIN_NAME.crt;
    #ssl_certificate_key /etc/nginx/certificate/$DOMAIN_NAME.key;
    #ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # don’t use SSLv3 ref: POODLE


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
        proxy_pass http://$UPSTREAM_NAME;
    }
}

# HTTP to HTTPS Redirect
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}
EOL

# Enable the site
ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/$DOMAIN_NAME

# Test and reload Nginx
nginx -t && systemctl reload nginx


