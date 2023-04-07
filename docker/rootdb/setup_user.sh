#!/usr/bin/env bash
set -Euox pipefail

# If user rootdb does not exist, create it now.
declare test_rootdb_user
test_rootdb_user=$(grep 'rootdb' /etc/passwd)

if [[ -z "${test_rootdb_user}" ]]; then

  echo "Creating rootdb user, with UID $1 & GID $2... "
  addgroup rootdb --gid "$2" &&
    adduser \
      --disabled-password \
      --gecos "" \
      --home "/home/rootdb" \
      --ingroup "rootdb" \
      --uid "$1" \
      rootdb

  mkdir /var/www/archives/
  chown -R rootdb:rootdb /var/www
  touch /var/log/php8.1-fpm.log
  chown rootdb:rootdb /var/log/php8.1-fpm.log
  chown rootdb:rootdb /usr/local/bin/docker-entrypoint.sh
  chmod +x /usr/local/bin/docker-entrypoint.sh
fi

su -c "/usr/local/bin/docker-entrypoint.sh" - rootdb

exit 0
