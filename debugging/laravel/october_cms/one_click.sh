#!/bin/bash
cwd=$(pwd)
mkdir /tmp/octobercms 2>/dev/null
mkdir /tmp/octobercms/mysqlconf 2>/dev/null
cp docker-compose.yml /tmp/octobercms/
cp xdebug.ini /tmp/octobercms/
cd /tmp/octobercms
docker-compose down
docker ps | grep 'octobercms' | awk '{print $1}' | xargs docker kill 
docker run -d --rm aspendigital/octobercms:latest
did=$(docker ps | grep 'octobercms' | awk '{print $1}')
docker cp $did:/var/www/html/ .
mkdir html/.vscode 2>/dev/null
cp $cwd/vscode-launch.json ./html/.vscode/launch.json
cp $cwd/my.cnf /tmp/octobercms/mysqlconf
docker kill $did
find ./html | grep -v '\.\/html$' | xargs -I {} chown www-data:www-data {}
# chown -R 33:33 ./html
# chown $(id -u):$(id -g) ./html
docker-compose up -d
sleep 30
docker-compose exec web php artisan october:up | tee -a $cwd/artisan_pass.log
docker-compose exec web composer self-update --2
docker-compose exec web composer self-update
docker-compose down
sed -i 's/host.docker.internal/'$(ip a s eth0 | head -n 3 | tail -n 1 | awk '{print $2}' | cut -d '/' -f 1)'/g' xdebug.ini
# replace the port number in the launch.json from the xdebug.ini file.
sed -i 's/'$(cat ./html/.vscode/launch.json | grep port | cut -d ':' -f 2 | cut -d ',' -f 1 | awk '{print $1}')'/'$(cat xdebug.ini | grep client_port | cut -d '=' -f 2)'/g' ./html/.vscode/launch.json
cd $cwd
export PASSWORD="root"
echo 'to change the default password:'
echo "sed -i 's/PASSWORD=root/PASSWORD=$PASSWORD/g' docker-compose.yml"
echo 'cd /tmp/octobercms; docker-compose up'
echo 'cd /tmp/octobercms; docker-compose exec mysql tail -F /var/log/mysqld.log'