# Build images

```bash
docker build --compress --force-rm --no-cache -t rootdb-memcached:latest -f ./Dockerfile_memcached .
docker build --compress --force-rm --no-cache -t rootdb-php-fpm:8.1 -f ./Dockerfile_php_fpm_8_1 .
docker build --compress --force-rm --no-cache -t rootdb-nginx:latest -f ./Dockerfile_nginx .
docker build --compress --force-rm --no-cache --build-arg VERSION=latest --build-arg UID=1000 --build-arg GID=1000 -t rootdb:latest -f ./Dockerfile_rootdb .
```

# Push images on dockerhub

```bash
docker tag rootdb-memcached:latest atomicwebsas/rootdb-memcached:latest
docker push atomicwebsas/rootdb-memcached:latest

docker tag rootdb-php-fpm:8.1 atomicwebsas/rootdb-php-fpm:8.1
docker push atomicwebsas/rootdb-php-fpm:8.1

docker tag rootdb-nginx:latest atomicwebsas/rootdb-nginx:latest
docker push atomicwebsas/rootdb-nginx:latest

docker tag rootdb:latest atomicwebsas/rootdb:latest
docker push atomicwebsas/rootdb:latest
```
