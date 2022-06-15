# author="Franck Pachot"
# description="YugabyteDB for labs and demos - creates a database with environment parameters compatible with the PostgreSQL image"
# Tested with:
# docker build -t pachot/yugabytedb . ; docker run --name yb -p 5433:5433 -p 7000:7000 -p 7002:7002 pachot/yugabytedb
# deployed with:
# docker build -t pachot/yugabytedb . && docker push pachot/yugabytedb
FROM docker.io/yugabytedb/yugabyte:latest
ENV POSTGRES_USER     demo
ENV POSTGRES_PASSWORD demo
ENV POSTGRES_DB       demo
ENV YUGABYTED_FLAGS --listen 0.0.0.0
CMD pip install --upgrade pip
CMD pip install sqlalchemy pandas psycopg2-yugabytedb 
ADD client ./client
EXPOSE 5433
EXPOSE 7000
EXPOSE 7002
ADD https://github.com/yugabyte/yugabyte-db/releases/download/v1.0.0-beta-yugabyted-ui/yugabyted-ui-1.0.0-linux-x86_64.tar.gz yugabyted-ui-1.0.0-linux-x86_64.tar.gz
RUN tar -xvf yugabyted-ui-1.0.0-linux-x86_64.tar.gz
CMD  \
     until PGPASSWORD=yugabyte bin/ysqlsh -v ON_ERROR_STOP=1 \
      -c "create database ${POSTGRES_DB} " \
      -c "create user ${POSTGRES_USER} password '${POSTGRES_PASSWORD}' " \
      2>/dev/null && ./yugabyted-ui ; do \
       echo 'Waiting for YugabyteDB to be up...' ; sleep 3 ; \
      done & \
     bin/yugabyted start --daemon=false --tserver_flags='ysql_enable_auth=true' $YUGABYTED_FLAGS \
