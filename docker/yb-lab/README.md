## run the lab

This generates a `docker-compose.yaml` to test multi-cloud, multi-region, multi-zone, multi-node, and with read replicas in a lab.

1. run `gen-yb-docker-compose.sh` to generate a `docker-compose.yaml` in the current directory, and start it. This creates a cluster with the settings are defined in the generation script:
 - the tservers will be created from yb-tserver-0 to get the number defined in `$number_of_tservers`
 - they will be distributed into `$list_of_clouds, `$list_of_regions, `$list_of_zones
 - the cloud.region.zone matching `$read_replica_regexp` will be read only (read replicas callsed 'ro')
 - master are created first, the number coming from `$replication_factor`
 - once the masters are created, `cluster-config` will set the primary and read replica topology. You can look at its log to check it
 - once all tservers are created, the `yb_servers()` topology is displayed

2. check the cluster on the console http://localhost:7000/tablet-servers

3. see demo app logs like `docker logs yb-lab_yb-demo_1`. It runs on thread for each line in `client/ybdemo.sql` connecting with settings in `hikari.properties`. The default displays info about the currently connected session, every 1 second. 

In order to play with High Availability, look at where a thread is connected, stop that node, like with `docker stop yb-tserver-6` and check application continuity from the yb-lab_yb-demo_n logs. And the console to see the new leader election. Restart the node, and see how it re-balances.

you can go to any node with something like `docker exec -it yb-lab_yb-demo_1 bash` and use `ysqlsh` like you would use `psql`. You can also connect to a node (the 5433 port from yb-tserver-0 is redirected from localhost:5433, yb-tserver-2 from 5434...)

In a yb-lab_yb-demo container you can also test when client connects to a specic zone by changing `dataSource.url` in `client/hikari.properties` to `jdbc:yugabytedb://yb-tserver-0:5433/yugabyte?user=yugabyte&password=yugabyte&loggerLevel=INFO&load-balance=true&topology-keys=cloud1.region1.zone1,cloud1.region1.zone2` and restart or run `(cd client && java -jar YBDemo.jar <<<"execute ybdemo(1)")`

In a yb-lab_yb-demo container you can also test writes:
```
cd client
cat > hikari.properties <<'INI'
dataSourceClassName=com.yugabyte.ysql.YBClusterAwareDataSource
dataSource.url=jdbc:yugabytedb://yb-tserver-0:5433/yugabyte?user=yugabyte&password=yugabyte&loggerLevel=INFO&load-balance=true&topology-keys=cloud1.region1.zone1,cloud1.region1.zone2
connectionTimeout=15000
autoCommit=true
INI
ysqlsh -h yb-tserver-0 -e -c "create table if not exists demo(id bigint generated always as identity, ts timestamptz default clock_timestamp(), message text, primary key(id hash));"
java -jar YBDemo.jar <<'SQL'
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
select format('Rows inserted in the last minute: %s',to_char(count(*),'999999999')) from demo where ts > clock_timestamp() - interval '1 minute';
SQL
```

## Screenshots

When started:

![image](https://user-images.githubusercontent.com/33070466/150552326-9d48f8d6-be31-405f-9506-2d7af65c6c49.png)

List of containers:

![image](https://user-images.githubusercontent.com/33070466/150541577-065967bc-4069-4eed-b939-3ac9a7d45bd5.png)

Cluster configuration from the logs of yb-lab_cluster-config:

![image](https://user-images.githubusercontent.com/33070466/150541630-c15da94d-e2a2-4492-a95c-0502d34109c2.png)

Smart driver demo:

![image](https://user-images.githubusercontent.com/33070466/150541806-2fba911b-c565-4cfc-a3f1-8edac6a3084d.png)

List of servers:

![image](https://user-images.githubusercontent.com/33070466/150541890-b67e2540-9526-41fa-81a0-206831deb30a.png)


