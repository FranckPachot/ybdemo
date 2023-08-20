Here is my lab to test various [YugabyteDB](https://www.yugabyte.com/) configurations locally in Docker. The `gen-yb-docker-compose.sh` generates a `docker-compose.yaml` to test multi-cloud, multi-region, multi-zone, multi-node, and with read replicas in a lab. It also creates some application containers running the YBDemo simple program from this repository. It is highly configurable, may change depending on my needs, so better look at the scripts to understand them. Or ask me ([@FranckPachot](https://twitter.com/FranckPachot))

A demo using this lab:
[Demo at DSS Asia 2022](https://www.youtube.com/watch?v=3dziM3kmTqI&list=PLTcxfDUDn3Zvm0SRBUJxpETtfYy1i_bAj)

I use docker-compose version 2. You may have to change some `-` to `_` in version one, like `%s/yb-lab-yb-tserver-n-${i}/yb-lab_yb-tserver-n_${i}/g`

# Run the lab

1. run `gen-yb-docker-compose.sh` to generate a `docker-compose.yaml` in the current directory, and start it. This creates a cluster with the settings are defined in the generation script though environment variables (and the first arg $1 of the script defines some configurations of interest)
 - the **tservers** will be created from yb-tserver-0 up to the number defined in `$number_of_tservers`
 - they will be distributed into `$list_of_clouds`, `$list_of_regions`, `$list_of_zones` **placement info** (of course all are on your laptop, those are just names ;)
 - the **cloud.region.zone** matching `$read_replica_regexp` will be **read replicas** (also called observers or witness replicas - they do not participate in raft quorum, they can lag but will never block writes)
 - **master** containers are created first, the number is the **replication factor** set in `$replication_factor`
 - once the masters are created, if `$read_replica_regexp` is defined, `cluster-config` will set the primary and read replica **topology**. You can look at its log to check what it defines. We this is set the tservers will be defined as `ro` for read replicas or `rw` for primary nodes depending on the pattern.
 - once all tservers are created, the `yb_servers()` topology is displayed

2. check the cluster on the console http://localhost:7000/tablet-servers as the port of the first master is exposed

3. see demo app logs like `docker logs yb-lab-yb-demo-connect-1`. It calls `client/ybdemo.sh` using [YBDemo.jar](https://github.com/FranckPachot/ybdemo/releases) to run threads. `client/ybdemo.sh` takes 2 parameters: the workload to run and the number of threads. There are commands to **init** (create the table), run **read**, **writes**, or, the default, just **connect** and show where it is connected. The connection settings are in `hikari.properties`. Only one endpoint is needed as the YugabyteDB JDBC Smart Driver will find the others. The default (connect) displays info about the currently connected session, every 1 second, with a prepared statement defined in HikariCP `connectionInitSql` to verify the smart driver behaviour.

4. see all logs with `docker-compose logs -tf` and have fun


You can also run this on Gitpod:

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/FranckPachot/ybdemo)

# Exercising ideas

## Test resilience

YugabyteDB, with a replication factor of RF=3, maintains continuous availability with one node failure. The quorum on writes guarantees a RPO=0 (no data loss) even with one node down (or two with RF=5) and Raft leader election guarantees RTO from 0 to 3 seconds (for the tablets that had their leader on the failed node, to elect a new leader). In order to play with High Availability, look at where a thread is connected. You can restart it (just in case) watch the logs:

```
docker restart yb-lab-yb-demo-init_1
docker restart yb-lab-yb-demo-write_1
docker logs -f yb-lab-yb-demo-write_1
```

You should see reads and writes distributed in http://localhost:7000/tablet-servers

When you stop another node that the one the thread is connected, you should see at most a few seconds wait. Leaders will be lected on other nodes and only followers remain. From the web console, the yb-tserver-1 taking no read/writes (they were rebalanced to the others) and becoming DEAD after 60 seconds (as set by `--follower_unavailable_considered_failed_sec`).

```
docker stop yb-tserver-1
```

Start it again (`docker start yb-tserver-1`) and the followers there will catch-up the last changes (kept by default 15 minutes as defined by `--log_min_seconds_to_retain`). If you don't start it up, the followers will be removed from the cluster and created elsewhere. This happens after `--follower_unavailable_considered_failed_sec` which also defaults to 15 minutes.

When you do the same with the node you are connected to, and , thanks to the connection pool and the smart driver, it will reconnect to another node and continue.

## Test elasticity

In order to play with elasticity, you can add more tservers, an easy way is to increase the number of replicas to `replicas: 3` for `yb-tserver-n` (they are defined to quickly add more node but they don't have specific placement info). 

```
docker-compose up -d --scale yb-tserver-n=3
```

On the console, you should see the number of tablets, and operations, re-balance to the new nodes

To remove t-servers, you should blacklist them first, like:

```
for i in {1..3} ; do docker exec -i yb-lab-yb-tserver-n-${i} bash <<< "/home/yugabyte/bin/yb-admin --master_addresses $(echo yb-master-{0..2}:7100|tr ' ' ,) change_blacklist ADD "'$(hostname):9100' ; done
```
Then check and wait for the completion of re-balancing:
```
docker exec -it yb-master-0 /home/yugabyte/bin/yb-admin --master_addresses $(echo yb-master-{0..2}:7100|tr ' ' ,) get_load_move_completion
```
Now, stop those servers:

 ````
 for i in {1..3} ; do docker stop yb-lab-yb-tserver-n-$i ; done
 ````

If the load balancing above was 100% completed, you can even remove them with their volume.

Then you can clear the black list (same as above with REMOVE instead of ADD):

```
for i in yb-lab-yb-tserver-n-{1..3} ; do docker exec -i yb-master-0 /home/yugabyte/bin/yb-admin --master_addresses $(echo yb-master-{0..2}:7100|tr ' ' ,) change_blacklist REMOVE $i ; done
```
You can also see the list of blacklisted servers in http://localhost:7000/cluster-config

When you want "dead" nodes to disappear from the UI http://localhost:7000/tablet-servers you can restart the master leader (find it from http://localhost:7000) to force a new leader election. In a lab, this can be: 

```
for i in yb-master-{0..2} ; do docker restart $i -t 5 ; done
```
In production, they will disapper after 24 hours (as set by `--hide_dead_node_threshold_mins`)

## Connect with psql

you can go to any node with something like `docker exec -it yb-lab-yb-demo_1 bash` and use `ysqlsh` like you would use `psql`. 

```
docker exec -it yb-tserver-0 ysqlsh -h yb-tserver-0
```

## Inspect the performance metrics

the `ybwr.sql` script collects the metrics from the tserver json endpoints, stores them, and displays a report every 10 seconds.
if the yb-lab-yb-demo-metrics service is not started you can run:
```
docker exec -it yb-lab-yb-demo-connect_1 bash client/ybdemo.sh ybwr
```

The most important metrics to identify any hotspots are `rows_inserted` for writes (those are key-value subdocuments, not SQL rows) and `rocksdb_number_db_seek`,`rocksdb_number_db_next` for reads and writes. The "%table" column shows the distribution of the per-tablet ones per the total for the table.

## Test JDBC Smart Driver

In a yb-lab-yb-demo container you can also test when client connects to a specic zone by changing `dataSource.url` in `client/hikari.properties` to

```
jdbc:yugabytedb://yb-tserver-0:5433/yugabyte?user=yugabyte&password=yugabyte&loggerLevel=INFO&load-balance=true&topology-keys=cloud1.region1.zone1,cloud1.region1.zone2
```

and restart a yb-demo server, or run:

```
docker start   yb-lab-yb-demo-connect-1
docker exec -i yb-lab-yb-demo-connect-1 bash -c "
cat > hikari.properties <<INI
dataSource.url=jdbc:yugabytedb://yb-tserver-0:5433/yugabyte?user=yugabyte&password=yugabyte&loggerLevel=INFO&load-balance=true&topology-keys=cloud1.region1.zone1,cloud1.region1.zone2
INI
grep -v ^dataSource.url client/hikari.properties >> hikari.properties
java -jar client/YBDemo.jar <<SQL
execute ybdemo(1000)
SQL
"

```

## Test follower reads

This can used the `docker-compose.yaml` generated by `sh gen-yb-docker-compose.sh rr` that creates some read replicas and starting no workload.
You can start only the database with:
```
docker-compose down
docker-compose up -d
docker-compose kill yb-demo-{read,write,connect}
docker-compose start yb-demo-init
```

This connects to one server and reads all rows in a loop:
```
docker exec -i yb-tserver-7 bash -c 'ysqlsh -h $(hostname)' <<'SQL'
\timing on
select count(*),current_setting('listen_addresses') from demo where id<=1000;
\watch 0.001
SQL
```
The console should show reads distributed on all servers, because the read goes to the LEADER tablet.

Now, the same with a follower read session:
```
docker exec -i yb-tserver-7 bash -c 'ysqlsh -h $(hostname)' <<'SQL'
set default_transaction_read_only = on;
set yb_read_from_followers=on;
set yb_follower_read_staleness_ms=2000;
\timing on
select count(*),current_setting('listen_addresses') from demo where id<=1000;
\watch 0.001
SQL
```
You should see all reads from the local server, as long as they have the tablet LEADER or FOLLOWER, and this also works from read replicas

# Screenshots

When started:

![image](https://user-images.githubusercontent.com/33070466/150552326-9d48f8d6-be31-405f-9506-2d7af65c6c49.png)

List of containers:

![image](https://user-images.githubusercontent.com/33070466/150541577-065967bc-4069-4eed-b939-3ac9a7d45bd5.png)

Cluster configuration from the logs of yb-lab-cluster-config:

![image](https://user-images.githubusercontent.com/33070466/150541630-c15da94d-e2a2-4492-a95c-0502d34109c2.png)

Smart driver demo:

![image](https://user-images.githubusercontent.com/33070466/150541806-2fba911b-c565-4cfc-a3f1-8edac6a3084d.png)

List of servers from the console:

![image](https://user-images.githubusercontent.com/33070466/150541890-b67e2540-9526-41fa-81a0-206831deb30a.png)

Performance metrics between two snapshots:

![Screenshot 2022-02-15 183046](https://user-images.githubusercontent.com/33070466/154118148-5906ed77-2240-4090-bf16-ab8ccddf29ec.png)
