#!/usr/bin/env sh
set -euo pipefail

echo "[setup conf dir] cleaning /etc/nginx/conf.d"
rm -f /etc/nginx/conf.d/default.conf

if [[ $NGINX_USE_SSL == 1 ]]; then
  echo "[setup conf dir] using ssl"
  rm -f /etc/nginx/templates/rootdb-api.conf.template
  rm -f /etc/nginx/templates/rootdb-frontend.conf.template
else
  echo "[setup conf dir] not using ssl"
  rm -f /etc/nginx/templates/rootdb-api_ssl.conf.template
  rm -f /etc/nginx/templates/rootdb-frontend_ssl.conf.template
fi
