run `gen-yb-docker-compose.sh` to generate a `docker-compose.yaml` in the current directory, to create a cluster with the settings are defined in the generation script

check the cluster on http://localhost:7000/tablet-servers

see demo app logs like `docker logs ybdemo-rf3_yb-demo_1`. It runs on thread for each line in `client/ybdemo.sql` connecting with settings in `hikari.properties`. The default displays info about the currently connected session, every 1 second.

Look at where a thread is connected, stop that node, like with `docker stop yb-tserver-6` and check application continuity, new leader election in the console, new connection from the pool. Restart the node, and see how it re-balances.


read replicas:

./bin/yb-admin modify_placement_info <placement_info> <replication_factor> [placement_uuid]
./bin/yb-admin add_read_replica_placement_info <placement_info> <replication_factor> [placement_uuid]


curl http://yb-master-0:7000/api/v1/cluster-config

curl http://yb-master-0:7000/cluster-config?raw

yb-admin -master_addresses yb-master-0:7100,yb-master-1:7100,yb-master-2:7100 modify_placement_info cloud1.region1.zone1,cloud1.region1.zone2,cloud1.region2.zone1,cloud1.region2.zone2 3 rw

yb-admin -master_addresses yb-master-0:7100,yb-master-1:7100,yb-master-2:7100 add_read_replica_placement_info cloud2.region1.zone1:1,cloud2.region1.zone2:1,cloud2.region2.zone1:1,cloud2.region2.zone2:1 1 ro

for i in {0..10} ; do docker stop yb-tserver-$i ; done

for i in {0..10} ; do docker start yb-tserver-$i ; done


for i in {0..10} ; do docker exec -i yb-tserver-$i 'rm /tmp/.yb.*/.s.PGSQL.5433.lock' ; done


                "--placement_uuid=rw",

