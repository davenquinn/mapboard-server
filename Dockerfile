# Dockerfile for setting up a basic version of this server.
# Topology features are not supported.
FROM node:12
RUN apt-get update && apt-get install -y libpq-dev postgresql-client

WORKDIR /app

COPY ./package.json  /app/package.json

RUN npm install

COPY ./ /app/

CMD ./run-docker
