#!/bin/bash
cwd=$(pwd)
wd=$(echo /tmp/laravel)
mkdir $wd 2> /dev/null
cd $wd
git clone https://github.com/aschmelyun/docker-compose-laravel
cd docker-compose-laravel
docker-compose down

mv docker-compose.root.yml docker-compose.yml
docker-compose up -d --build site
rm ./src/README.md
docker-compose run --rm composer create-project laravel/laravel .
# echo '<?php phpinfo(); ?>' > ./src/public/index.php
echo "Route::get('/hacking', function () {
    return view('hacking');
});" | tee -a src/routes/web.php

if grep -q Xdebug ./dockerfiles/php.root.dockerfile
then
    echo 'already set.'
else
echo '# Add xdebug
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS
RUN apk add --update linux-headers
RUN pecl install xdebug
RUN docker-php-ext-enable xdebug
RUN apk del -f .build-deps

# Configure Xdebug
RUN echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.log=/var/www/html/xdebug.log" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.discover_client_host=1" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_port=9000" >> /usr/local/etc/php/conf.d/xdebug.ini' | tee -a ./dockerfiles/php.root.dockerfile
sed -i 's/host.docker.internal/'$(ip a s eth0 | head -n 3 | tail -n 1 | awk '{print $2}' | cut -d '/' -f 1)'/g' ./dockerfiles/php.root.dockerfile
fi

docker-compose down
docker-compose up -d --build site

# making the vscode launch file:
mkdir src/.vscode 2>/dev/null
cp $cwd/vscode-launch.json ./src/.vscode/launch.json
sed -i 's/'$(cat ./src/.vscode/launch.json | grep port | cut -d ':' -f 2 | cut -d ',' -f 1 | awk '{print $1}')'/'$(cat ./dockerfiles/php.root.dockerfile | grep client_port | cut -d '=' -f 2 | cut -d '"' -f 1)'/g' ./src/.vscode/launch.json

# you can either print phpinfo or xdebug_info()
#echo '<?php phpinfo(); ?>' > ./src/resources/views/hacking.blade.php
echo '<?php xdebug_info(); ?>' > ./src/resources/views/hacking.blade.php

curl -Ss 'http://localhost/hacking' | grep xdebug | wc
code ./src/ --no-sandbox --user-data-dir /tmp/vscode
