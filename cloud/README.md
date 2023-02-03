Creates a free database on YugabyteDB cloud and starts demo
```
. yb-managed-free.sh <<'API_CREDENTIALS'
eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJBcGlKd3QiLCJzdWIiOiIyN2NmZTg4OS03YjdiLTQyYmMtYWU1Mi1hYWFkZTNkMzFiZjQiLCJpc3MiOiJmcGFjaG90QHl1Z2FieXRlLmNvbSIsImV4cCI6MTcwNjk0ODY1NiwiaWF0IjoxNjc1NDEyNjU2LCJqdGkiOiI5ZjI4YzE1MC05NTg4LTQxM2QtODc0MS1hZjAzMmI4NTM1ODkifQ.ftcVHaGBLwVgFVDoxQ03-dr9OTL0QKhgZ5AcIEEL-FY
8c17af53-3c7c-4e76-a530-768ccdfd75b1
684d1eeb-4c50-4678-a925-1e7d777d6bd8
API_CREDENTIALS

cat       ../docker/yb-lab/client/hikari.properties . | sed -e "/dataSource.url=/s!=.*!=jdbc:yugabytedb://$PGHOST:$PGPORT/$PGDATABASE?user=$PGUSER\&password=$PGPASSWORD\&sslmode=$PGSSLMODE\&connectTimeout=15\&loggerLevel=INFO!" > ./hikari.properties
java -jar ../docker/yb-lab/client/YBDemo.jar <<<'select 1'

```
