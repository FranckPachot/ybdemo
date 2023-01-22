This Dockerfile is based on the [yugabytedb/yugabyte](https://hub.docker.com/r/yugabytedb/yugabyte) image and adds automatic startup of the database that is compatible with the [postgres](https://hub.docker.com/_/postgres/) image (with POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB environment variables)

The goal is to use it as a replacement of the PostgreSQL image for tests environements to validate the application on YugabyteDB. 

Future improvements:
- possibility to create a multi-node cluster (Replication Factor 3)
- possibility to start with the real PostgreSQL (in case some initial DDL are not supported on YugabyteDB) and then restart with YugabyteDB (with a pg_dump of the previous done during a clean stop)



