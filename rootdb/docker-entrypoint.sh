#!/usr/bin/env bash
set -Euox pipefail

# If user rootdb does not exist, create it now.
declare test_rootdb_user
test_rootdb_user=$(grep 'rootdb' /etc/passwd)

if [[ -z "${test_rootdb_user}" ]]; then

  echo "Creating rootdb user, with UID ${UID} & GID ${GID}... "
  addgroup rootdb --gid "${UID}" &&
    adduser \
      --disabled-password \
      --gecos "" \
      --home "/home/rootdb" \
      --ingroup "rootdb" \
      --uid "${GID}" \
      rootdb
fi

[[ ! -d /var/www/archives ]] && mkdir /var/www/archives
chown -R rootdb:rootdb /var/www

[[ ! -f /var/log/php8.1-fpm.log ]] && touch /var/log/php8.1-fpm.log

chown rootdb:rootdb /var/log/php8.1-fpm.log
chown rootdb:rootdb /usr/local/bin/docker-entrypoint.sh
chmod +x /usr/local/bin/docker-entrypoint.sh
chown rootdb:rootdb /usr/local/bin/setup_rootdb.sh
chmod +x /usr/local/bin/setup_rootdb.sh
chown rootdb:rootdb /var/www/.api_env
chown rootdb:rootdb /var/www/.app-config.js

su -c "/usr/local/bin/setup_rootdb.sh ${VERSION}" - rootdb

exit 0

# Will run `php-fpm` by default
#exec "$@"
