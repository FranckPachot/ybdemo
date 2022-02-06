# YBDemo

YBDemo is a simple Java program that creates an [HikariCP](https://github.com/brettwooldridge/HikariCP) connection pool from the `hikari.properties` file in the current directory, and takes SQL statements to execute as lines from stdin. There's no multi-line statement: each line is a thread, executing the statement in a loop. The goal is to make it easy to run a demo with concurrent threads by providing the set of queries in a simple way, interactive or though file redirection. Only the first column of the first row is displayed, I use `row_to_json()` or `json_agg()` to format a larger result into one value. The thread stops if no row is returned, I use RETURNING to get a row from DML.

The goal is to run it on PostgreSQL compatible databases, especially distributed ones like [YugabyteDB](https://www.yugabyte.com/). The [.jar](https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar) includes the YugabyteDB JDBC driver, which is a fork of the PostgreSQL one with cluster-aware additions.

Error management is aimed demos on distributed SQL databases, where optimistic locking requires the application to implement a retry logic. In case of errors, depending on the [SQLSTATE](https://www.postgresql.org/docs/current/errcodes-appendix.html), we continue the loop to retry, stop the thread, or stop the program.

On SQLException the SQLSTATE determines the behavior:
- SQLSTATE 02000 is "no data". The thread is stopped, but others continue. I use this to run a statement once, like creating a table (there's a 1 second delay between thread starts so the others should see the table)
- SQLSTATE 42xxx are syntax error. The program stops because you probably want to fix your demo statements
- SQLSTATE 5xxxx are system errors. The program stops because you probably want to fix your demo environment
- SQLSTATE 40001 are serialization errors. They are retried with exponential backoff until a max_retries limit.
- SQLSTATE 40P01 are deadlocks. They are retried with exponential backoff until a max_retries limit.
- Other SQLSTATE stop the program because you probably want to define how to handle them.

On SQLTransientConnectionException, the thread continues to retry, without waiting because there's already a timeout set in the connection pool settings. This error must be handled because transcient connection failures are exected in a distributed database, during unplanned (node, zone, region down) or planned (rolling upgrades) events.

The code is simple, in order to show how to handle errors and retry logic in a distributed SQL database like [YugabyteDB](https://www.yugabyte.com), the open-source SQL distributed database, which is still available when a node is down. This is why those errors allow immediate retry. In this demo, each thread runs always the same statement, so the retry logic is just continuing the loop (and increase the retry count). In a application, you may have more logic related to retries.

## YugabyteDB 

The docker/yb-lab folder has a docker-compose example file to start a local cluster

With the YugabyteDB Smart Driver (`YBClusterAwareDataSource`) there is only the need to define one endpoint (or a list to try in order) and other nodes will be discovered dynamically. Here is an example:
```
dataSourceClassName=com.yugabyte.ysql.YBClusterAwareDataSource
dataSource.url=jdbc:yugabytedb://47cc8863-9344-4a9c-bc02-0dd9f843dceb.cloud.yugabyte.com:5433/yugabyte?user=yugabyte&password=yugabyte&loggerLevel=OFF
```

## Prepared Statements 

YugabyteDB is compatible with PostgreSQL. We can use the Hikari `connectionInitSql` to run `PREPARE` statements so that they can simply be called with an `EXECUTE`.

The example `hikari.properties` defines:
```
## ybdemo(seconds) displays connection info and waits seconds
connectionInitSql=prepare ybdemo(int) as select \n\
 format('%8s pid: %8s %25s %16s %10s',to_char(now(),'DD-MON HH24:MI:SS') \n\
 ,pg_backend_pid(),'  host: '||lpad(host,16),cloud||'.'||region||'.'||zone,node_type) \n\
 as yb_server, pg_sleep($1/1000) \n\
 from (select host(inet_server_addr()) host) as server \n\
 natural left join (select host,node_type,cloud,region,zone from yb_servers()) servers
```
This query will show connection information (pid and host) as well as YugabyteDB cluster topology information (`yb_servers()`). It also waits, with `pg_sleep()` to keep connection active for a while, so that the conenction pool allocates multiple connections, and we can see how they are load balanced.

## YBDemo Usage

The following, with the package built with `mvn package`, will run 3 thread displaying this info every second:
```
java -jar ./target/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar <<'SQL'
execute ybdemo(1000);
execute ybdemo(1000);
execute ybdemo(1000);
SQL
```
The output is:
```
61  [main] INFO com.zaxxer.hikari.HikariDataSource - HikariPool-1 - Starting...
507 [main] INFO com.zaxxer.hikari.HikariDataSource - HikariPool-1 - Start completed.
--------------------------------------------------
sql executed in each new connection:
--------------------------------------------------
prepare ybdemo(int) as select
format('%8s pid: %8s %25s %16s %10s',to_char(now(),'DD-MON HH24:MI:SS')
,pg_backend_pid(),'  host: '||lpad(host,16),cloud||'.'||region||'.'||zone,node_type)
as yb_server, pg_sleep($1/1000)
from (select host(inet_server_addr()) host) as server
natural left join (select host,node_type,cloud,region,zone from yb_servers()) servers
--------------------------------------------------
input lines will start a thread to execute in loop
--------------------------------------------------
 Thread-1   1038ms: 10-JAN 08:18:17 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-2   1131ms: 10-JAN 08:18:17 pid:     4769    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-3   1224ms: 10-JAN 08:18:17 pid:     4717    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-1   1008ms: 10-JAN 08:18:18 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-2   1008ms: 10-JAN 08:18:18 pid:     4769    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-3   1008ms: 10-JAN 08:18:18 pid:     4717    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-1   1007ms: 10-JAN 08:18:19 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-2   1008ms: 10-JAN 08:18:19 pid:     4769    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-3   1007ms: 10-JAN 08:18:19 pid:     4717    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-1   1007ms: 10-JAN 08:18:20 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-2   1008ms: 10-JAN 08:18:20 pid:     4769    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-3   1008ms: 10-JAN 08:18:20 pid:     4717    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-1   1007ms: 10-JAN 08:18:21 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-2   1008ms: 10-JAN 08:18:21 pid:     4769    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-3   1008ms: 10-JAN 08:18:21 pid:     4717    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-1   1006ms: 10-JAN 08:18:22 pid:     5931    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
```

As I called a 1000 milliseconds `pg_sleep`, the call latency is visible by subtracting 1000 milliseconds to the response time: between 7 and 8 milliseconds between Availability Zones, except the first ones after connection, in hundreds of millisecond. This is why we use a connection pool, and can se 

If you defined a short duration for re-reconnecting, like this 300s with `maxLifetime=300000`, you will see the pid and host change after 5 minutes. This helps to re-balance the load when nodes are added (and automatically discovered by the Smart Driver)

## Retriable failures

If one node is down for planned operation, like rolling upgrade, or unplanned outage, like AZ or region failure, the error is detected but all application threads can continue:
```
 Thread-3   1007ms: 10-JAN 08:35:14 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-1   1008ms: 10-JAN 08:35:15 pid:    10318    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-2   1006ms: 10-JAN 08:35:15 pid:    11791    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-3   1007ms: 10-JAN 08:35:15 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-1   1008ms: 10-JAN 08:35:16 pid:    10318    host:    172.159.56.80 aws.eu-west-1.eu-west-1c    primary
 Thread-2   1006ms: 10-JAN 08:35:16 pid:    11791    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-3   1007ms: 10-JAN 08:35:16 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
46603 [Thread-1] WARN com.zaxxer.hikari.pool.ProxyConnection - HikariPool-1 - Connection com.yugabyte.jdbc.PgConnection@27b8f957 marked as broken because of SQLSTATE(57P01), ErrorCode(0)
com.yugabyte.util.PSQLException: FATAL: terminating connection due to administrator command
        at com.yugabyte.core.v3.QueryExecutorImpl.receiveErrorResponse(QueryExecutorImpl.java:2679)
        at com.yugabyte.core.v3.QueryExecutorImpl.processResults(QueryExecutorImpl.java:2359)
        at com.yugabyte.core.v3.QueryExecutorImpl.execute(QueryExecutorImpl.java:349)
        at com.yugabyte.jdbc.PgStatement.executeInternal(PgStatement.java:484)
        at com.yugabyte.jdbc.PgStatement.execute(PgStatement.java:404)
        at com.yugabyte.jdbc.PgStatement.executeWithFlags(PgStatement.java:325)
        at com.yugabyte.jdbc.PgStatement.executeCachedSql(PgStatement.java:311)
        at com.yugabyte.jdbc.PgStatement.executeWithFlags(PgStatement.java:287)
        at com.yugabyte.jdbc.PgStatement.executeQuery(PgStatement.java:239)
        at com.zaxxer.hikari.pool.ProxyStatement.executeQuery(ProxyStatement.java:110)
        at com.zaxxer.hikari.pool.HikariProxyStatement.executeQuery(HikariProxyStatement.java)
        at YBDemo.run(YBDemo.java:23)
 Thread-1    734ms SQLSTATE(57P01) com.yugabyte.util.PSQLException: FATAL: terminating connection due to administrator command
 Thread-2   1007ms: 10-JAN 08:35:17 pid:    11791    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-3   1007ms: 10-JAN 08:35:17 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-1   1148ms: 10-JAN 08:35:18 pid:    10727    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-2   1007ms: 10-JAN 08:35:18 pid:    11791    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-3   1007ms: 10-JAN 08:35:18 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-1   1008ms: 10-JAN 08:35:19 pid:    10727    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
 Thread-2   1006ms: 10-JAN 08:35:19 pid:    11791    host:   172.159.19.128 aws.eu-west-1.eu-west-1a    primary
 Thread-3   1008ms: 10-JAN 08:35:19 pid:    10433    host:   172.159.43.191 aws.eu-west-1.eu-west-1b    primary
```
Here Thread-1 was connected to host 172.159.56.80 which crashed, and this thread has re-connected to 172.159.43.191 immediately, within hundreds of milliseconds. The other threads go with no interruption at all.

## Cluster Topology

By default, the driver load-balances to all nodes. This can be restricted with `topology-keys` parameter, in the JDBC url, like this: `&topology-keys=aws.eu-west-1.eu-west-1a,aws.eu-west-1.eu-west-1b` if you want to connect only to those two Availability Zones

## Quick Start

Get the .jar and example .properties:
```
wget -c -O YBDemo.jar https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar
wget -c -O hikari.properties https://raw.githubusercontent.com/FranckPachot/ybdemo/main/hikari.properties
```
Change the connection string to your YugabyteDB database and run it:
```
for i in {1..3} ; do echo "execute ybdemo(1000)" ; done | java -jar YBDemo.jar
```

Or use it interactively entering the statements that you want to run, one line command per thread.

