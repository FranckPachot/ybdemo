# author="Franck Pachot"
# description="YugabyteDB for labs and demos - creates a database with environment parameters compatible with the PostgreSQL image"
FROM docker.io/yugabytedb/yugabyte:latest
ENV POSTGRES_USER     demo
ENV POSTGRES_PASSWORD demo
ENV POSTGRES_DB       demo
ENV YUGABYTED_FLAGS --listen 0.0.0.0
CMD pip install --upgrade pip
CMD pip install sqlalchemy pandas psycopg2-yugabytedb 
ADD client .
EXPOSE 5433
EXPOSE 7000
CMD  \
     until PGPASSWORD=yugabyte bin/ysqlsh -v ON_ERROR_STOP=1 \
      -c "create database ${POSTGRES_DB} " \
      -c "create user ${POSTGRES_USER} password '${POSTGRES_PASSWORD}' " \
      2>/dev/null ; do \
       echo 'Waiting for YugabyteDB to be up...' ; sleep 3 ; \
      done & \
     bin/yugabyted start --daemon=false --tserver_flags='ysql_enable_auth=true' $YUGABYTED_FLAGS \
