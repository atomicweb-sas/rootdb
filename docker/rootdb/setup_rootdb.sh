#!/usr/bin/env bash
set -Eeuo pipefail

declare VERSION=$1

declare www_dir="/var/www"
declare api_dir="${www_dir}/api"
declare frontend_dir="${www_dir}/frontend"
declare api_frontend_themes_dir="${api_dir}/frontend-themes"
declare api_env_file="${api_dir}/.env"
declare front_app_config_js_file="${frontend_dir}/app-config.js"
declare root_api_env_file="${www_dir}/.api_env"
declare root_front_app_config_js_file="${www_dir}/.app-config.js"

declare api_db_init_file="${www_dir}/.api_db_initialized"
declare api_init_file="${www_dir}/.api_initialized"
declare front_init_file="${www_dir}/.front_initialized"

declare rdb_init_file="${www_dir}/.rdb_initialized"
declare rdb_init_log_file="${www_dir}/.rdb_initialization.log"
declare rdb_init_from_file="${www_dir}/.rdb_initialized_from"
declare rdb_upgraded_to="${www_dir}/.rdb_upgraded_to"
declare rdb_archive_version="${VERSION}"
declare rdb_current_version
declare rdb_online_latest_version
declare rdb_online_archive_url="https://builds.rootdb.fr/rootdb"
declare rdb_online_latest_version_url="${rdb_online_archive_url}/latest"

# To create relative path instead of hard path. Because when this image is use in standalone mode
# nginx/apache need to access /var/www/api|frontend (which are symllinks) from the outside.
declare rdb_archives_dir="./archives"
declare rdb_version_dir

[[ -f ${rdb_init_log_file} ]] && rm -f ${rdb_init_log_file}

[[ ! -d ${rdb_archives_dir} ]] && mkdir ${rdb_archives_dir}

cd "${www_dir}"

function getRootDBCurrentVersion() {

  echo "Fetching RootDB version..."
  rdb_current_version=$(cat "${api_dir}/.version")

  if [[ -z "${rdb_current_version}" ]]; then
    echo "[ERROR] Unable to fetch RootDB version !"
    exit 1
  fi

  echo "Detected current RootDB version : ${rdb_current_version}"
}

# @param1 string version
# @param2 int step :
#         - 1 - download and set version
#         - 2 - extract
#         - 3 - delete archive
function manageRootDBArchive() {

  declare archive_file="rootdb-$1.tar.bz2"

  if [[ $2 == 1 ]]; then

    echo "Downloading RootDB... ( ${archive_file} )"
    curl -O "${rdb_online_archive_url}/${archive_file}" >>"${rdb_init_log_file}" 2>&1

    echo "Getting RootDB version from downloaded archive..."
    rdb_archive_version=$(tar -tjf "${archive_file}" | cut -f1 -d"/" | sort | uniq)
    [[ ! -f "rootdb-${rdb_archive_version}.tar.bz2" ]] && mv "${archive_file}" "rootdb-${rdb_archive_version}.tar.bz2"
    rdb_version_dir="${rdb_archives_dir}/${rdb_archive_version}"
    echo "Archive RootDB version : ${rdb_archive_version}"
  fi

  if [[ $2 == 2 ]]; then

    [[ -d "${rdb_version_dir}" ]] && rm -Rf "${rdb_version_dir}"
    echo "Extracting code... ( in ${rdb_archives_dir} ) "
    tar -xjf "${archive_file}" -C "${rdb_archives_dir}" #>>"${rdb_init_log_file}" 2>&1
    echo "Archive directory for ${rdb_archive_version}: ${rdb_version_dir}"
  fi

  if [[ $2 == 3 ]]; then
    echo "Deleting downloaded archive..."
    rm -f "${archive_file}" >>"${rdb_init_log_file}"
  fi
}

function createSymLinks() {

  echo "Creating symlinks..."
  rm -f "${api_dir}"                 # /var/www/api - symlink
  rm -f "${frontend_dir}"            # /var/www/frontend- symlink
  rm -f "${api_frontend_themes_dir}" # /var/www/api/frontend-themes - symlink

  ln -s "${rdb_version_dir}/api" "${api_dir}"
  ln -s "${rdb_version_dir}/frontend" "${frontend_dir}"
  ln -s "../../.${rdb_version_dir}/frontend/themes" "${api_frontend_themes_dir}"
}

# Copy the initial API .env file in root dir.
function apiInitialization() {

  if [[ ! -f "${api_init_file}" ]]; then

    echo "[API] Handling .env_api file..."

    # If .api_env is not here, we get a default one from archive.
    if [[ ! -f "${root_api_env_file}" ]]; then

      echo "[API] copy ${rdb_version_dir}/api/.env -> ${root_api_env_file}"
      cp "${rdb_version_dir}/api/.env" "${root_api_env_file}"

    else
      echo "[API] Using mounted .env_api file..."
    fi

    # Deleting existing /var/www/archives/<version>/api/.env (from the archive)
    rm -f "${rdb_version_dir}/api/.env"

    echo "[API] link ${root_api_env_file} -> ${api_env_file}"
    ln -s "${root_api_env_file}" "${api_env_file}"

    echo
    touch "${api_init_file}"
  fi
}

# Copy the initial front .app-config.js file in root dir.
function frontInitialization() {

  if [[ ! -f "${front_init_file}" ]]; then

    echo "[Front] Handling app-config.js file..."

    # If .app-config.js is not here, we get a default one from archive.
    if [[ ! -f "${root_front_app_config_js_file}" ]]; then

      echo "[Front] copy ${rdb_version_dir}/frontend/app-config.js -> ${root_front_app_config_js_file}"
      cp "${rdb_version_dir}/frontend/app-config.js" "${root_front_app_config_js_file}"

    else
      echo "[API] Using mounted app-config.js file..."
    fi

    # Deleting existing /var/www/archives/<version>/frontend/app-config.js (from the archive)
    rm -f "${rdb_version_dir}/frontend/app-config.js"

    echo "[Front] link ${root_front_app_config_js_file} -> ${front_app_config_js_file}"
    ln -s "${root_front_app_config_js_file}" "${front_app_config_js_file}"

    echo
    touch "${front_init_file}"
  fi
}

# @param int step :
#        - 1 - database initialization
#        - 2 - database backup
function handleAPIDB() {

  declare db_host
  declare db_port
  declare db_database
  declare db_username
  declare db_password
  declare app_env

  db_host=$(grep 'DB_HOST' ${api_env_file} | sed "s|DB_HOST=||g")
  db_port=$(grep 'DB_PORT' ${api_env_file} | sed "s|DB_PORT=||g")
  db_database=$(grep 'DB_DATABASE' ${api_env_file} | sed "s|DB_DATABASE=||g")
  db_username=$(grep 'DB_USERNAME' ${api_env_file} | sed "s|DB_USERNAME=||g")
  db_password=$(grep 'DB_PASSWORD' ${api_env_file} | sed "s|DB_PASSWORD=||g")
  app_env=$(grep 'APP_ENV' ${api_env_file} | sed "s|APP_ENV=||g")

  if [[ $1 == 1 ]]; then

    echo -en "[API] database already initialized ? "
    if [[ ! -f "${api_db_init_file}" ]]; then

      echo "no"
      echo
      echo "[API] Wait 5s before \"${app_env}\" database initialization..."
      sleep 5

      php "${api_dir}/artisan" db:wipe -n --force >>"${rdb_init_log_file}" 2>&1

      echo "[API] database initialization..."
      echo "[API] If \"Done\" is not displayed below, check log file here: ${rdb_init_log_file} (container path)"

      mysql -h "${db_host}" -P "${db_port}" -u "${db_username}" -p"${db_password}" "${db_database}" <"${api_dir}/storage/app/seeders/${app_env}/seeder_init.sql"

      echo
      echo "[API] Done."
      echo
      touch "${api_db_init_file}"
    else

      echo "yes"
      echo "Nothing to do."
    fi

  fi

  if [[ $1 == 2 ]]; then

    echo -en "[API] Database backup... "
    declare api_db_backup_pathname
    api_db_backup_pathname="${rdb_archives_dir}/${db_database}-${rdb_current_version}.sql.gz"
    echo "archive pathname : ${api_db_backup_pathname}"

    mysqldump -u "${db_username}" -p"${db_password}" -h "${db_host}" "${db_database}" --single-transaction --complete-insert --add-drop-table | gzip >"${api_db_backup_pathname}"

    declare api_db_backup_size
    api_db_backup_size=$(stat -c "%s" "${api_db_backup_pathname}")
    if [[ "${api_db_backup_size}" -le 100 ]]; then

      rm -f "${api_db_backup_pathname}"
    fi

    if [[ ! -f "${api_db_backup_pathname}" ]]; then

      echo "[ERROR] Unable to backup database, stopping here."
      exit 1

    else
      echo "[API] Done."
    fi
  fi
}

#
# Container, first run.
#
echo -en "RootDB initialized ? "
if [[ ! -f "${rdb_init_file}" ]]; then

  echo "no"
  echo
  echo "Initializing..."

  # Download and set version
  manageRootDBArchive "${rdb_archive_version}" 1
  # Extract
  manageRootDBArchive "${rdb_archive_version}" 2
  # Delete archive
  manageRootDBArchive "${rdb_archive_version}" 3
  createSymLinks
  apiInitialization
  handleAPIDB 1
  frontInitialization

  # Storing version used for initialization.
  echo "${rdb_archive_version}" >"${rdb_init_from_file}"

  echo
  touch "${rdb_init_file}"

#
# Container restarted.
#
else

  echo "yes"

  # Will return "1" if latest version | VERSION > current version
  declare semver_compare_res
  declare rdb_version_to_upgrade

  getRootDBCurrentVersion

  # We check if we need to upgrade if admin asked for "latest" version...
  if [[ "${VERSION}" == "latest" ]]; then

    rdb_online_latest_version=$(curl "${rdb_online_latest_version_url}" | head -1)

    # Issue while fetching online latest version available
    if [[ -z "${rdb_online_latest_version}" ]]; then

      echo "[WARNING] Unable to fetch latest RootDB version available !"
      echo "[WARNING] But it's not a big deal, we start the service."
      semver_compare_res=0
    else

      echo "Latest RootDB version available : ${rdb_online_latest_version}"
      semver_compare_res=$(semver compare "${rdb_online_latest_version}" "${rdb_current_version}")
      rdb_version_to_upgrade="${rdb_online_latest_version}"
    fi
  # ... or if admin asked for a specific version  .
  else

    echo "Custom VERSION asked : ${VERSION}"
    semver_compare_res=$(semver compare "${VERSION}" "${rdb_current_version}")
    rdb_version_to_upgrade="${VERSION}"
  fi

  # We have to upgrade.
  if [[ "${semver_compare_res}" == "1" ]]; then

    echo "Upgrading from ${rdb_current_version} to ${rdb_version_to_upgrade}"

    # Backup database
    handleAPIDB 2

    echo "Pull RootDB code..."
    manageRootDBArchive "${rdb_archive_version}" 1
    echo "Archive RootDB version : ${rdb_archive_version}"

    # To reinitialize .env & app-config.js symlinks.
    rm -f "${api_init_file}"
    rm -f "${front_init_file}"

    # Extract
    manageRootDBArchive "${rdb_archive_version}" 2
    createSymLinks
    apiInitialization
    frontInitialization

    echo "[API] SQL migrations..."
    php "${api_dir}/artisan" migrate -n --force >>"${rdb_init_log_file}" 2>&1
    echo "${rdb_archive_version}" >"${rdb_upgraded_to}"

    # Delete archive
    manageRootDBArchive "${rdb_archive_version}" 3

  else

    # Backup database
    echo "Nothing to do."
  fi
fi

#
# API services
#
touch /var/www/api/storage/logs/websocket.log
touch /var/www/api/storage/logs/worker.log

echo
echo "Content of \"/var/www\" directory :"
ls -lha /var/www
echo

echo "Starting services with supervisor..."
/usr/bin/supervisord -c /etc/supervisord.conf
echo

echo "Starting PHP-FPM (foreground)..."
/usr/sbin/php-fpm8.1 -F
