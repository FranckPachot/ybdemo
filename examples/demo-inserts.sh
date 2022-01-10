(cd yb-rf3 && docker-compose up -d)

docker exec -i yb-tserver-1 bash <<'EXEC'
curl -sL https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar > YBDemo.jar
cat > hikari.properties <<CAT
dataSourceClassName=com.yugabyte.ysql.YBClusterAwareDataSource
dataSource.url=jdbc:yugabytedb://$(hostname)/yugabyte?user=yugabyte
connectionTimeout=5000
minimumIdle=3
maximumPoolSize=6
maxLifetime=300000
idleTimeout=120000
autoCommit=true
connectionInitSql=create table if not exists ybdemo(id bigint generated always as identity, ts timestamptz default now(), pid int default pg_backend_pid(), host text default host(inet_server_addr()), message text); prepare insert(text) as insert into ybdemo(message) values ('$1') returning format('%20s %s %s %s %s','',ts,pid,host,message);
autoCommit=true
CAT
java -jar YBDemo.jar <<'SQL'
execute insert('hello');
execute insert('hola');
execute insert('bonjour');
select format('%12s rows/s',to_char(count(*)/extract(epoch from max(ts)-min(ts)),'99999999.99')) from ybdemo;
delete from ybdemo where ts>now()-interval'1 minute';
SQL
EXEC
