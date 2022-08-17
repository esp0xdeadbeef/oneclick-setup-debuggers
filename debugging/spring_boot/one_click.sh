#!/bin/bash
cwd=$(pwd)
wd=$(echo /tmp/spring_boot)
mkdir $wd 2> /dev/null
cd $wd
# cp -r $cwd/* .
docker-compose down
git clone https://github.com/Kikiodazie/BlogAPI

cd BlogAPI

if grep -q finalName ./pom.xml
then
    echo 'already set.'
else
    echo 'changing now'
    sed -i 's|<build>|<build>\n\t<finalName>blog-api-docker</finalName>|g' ./pom.xml
fi

debug_port=5005
IP=localhost
port=8080
# # normal (remove lines after `mkdir ./.vscode 2>/dev/null`):
# mvn install -DskipTests
# # with debugging:
mvn install -DskipTests -Drun.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=$debug_port"

echo 'FROM openjdk:latest
ADD target/blog-api-docker.jar blog-api-docker.jar
#ENTRYPOINT ["java", "-jar","blog-api-docker.jar"]
ENTRYPOINT ["java","-agentlib:jdwp=transport=dt_socket,address=*:'$debug_port',server=y,suspend=n", "-jar","blog-api-docker.jar"]
EXPOSE '$debug_port'
EXPOSE '$port'' | tee Dockerfile

docker build --no-cache -t blog-api-docker . 

echo 'version: "3.1"
services:
  API:
    image: "blog-api-docker"
    ports:
      - "'$port':'$port'"
      - "'$debug_port':'$debug_port'"
    depends_on:
      PostgreSQL:
        condition: service_healthy
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://PostgreSQL:5432/postgres
      - SPRING_DATASOURCE_USERNAME=postgres
      - SPRING_DATASOURCE_PASSWORD=password
      - SPRING_JPA_HIBERNATE_DDL_AUTO=update

  PostgreSQL:
    image: postgres
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5' | tee docker-compose.yml

docker-compose up -d


echo 'Waiting to post this:'
echo '{
    "title": "Test Post",
    "post": "This POST request creates a Post"
}' | tee postdata.json
sleep 10
curl --json @./postdata.json http://$IP:$port/posts
sed -i 's/This POST request creates a Post/Different content/g' ./postdata.json
echo 'posting this now:'
cat ./postdata.json
# make a second request that is edited.
curl --json @./postdata.json http://$IP:$port/posts
# get all the posts
curl -X GET http://$IP:$port/posts


cd $wd/BlogAPI
mkdir ./.vscode 2>/dev/null

echo 'writing vscode debug info and starting code in current location:'
echo '{
   "version": "0.2.0",
   "configurations": [
       {
        "type": "java",
        "name": "Attach to Remote Program",
        "request": "attach",
        "hostName": "'$IP'",
        "port": "'$debug_port'"
    }
   ]
}' > ./.vscode/launch.json

code ./ --no-sandbox --user-data-dir /tmp/vscode
