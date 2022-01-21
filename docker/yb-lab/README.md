
This generates a `docker-compose.yaml` to test multi-cloud, multi-region, multi-zone, multi-node, and with read replicas in a lab.

1. run `gen-yb-docker-compose.sh` to generate a `docker-compose.yaml` in the current directory, and start it. This creates a cluster with the settings are defined in the generation script:
 - the tservers will be created from yb-tserver-0 to get the number defined in `$number_of_tservers`
 - they will be distributed into `$list_of_clouds, `$list_of_regions, `$list_of_zones
 - the first ones are read-write (primary cluster called 'rw'
 - the last `$number_of_read_replicas` ones will be read only (read replicas callsed 'ro')
 - master are created first, the number coming from `$replication_factor`
 - once the masters are created, `cluster-config` will set the primary and read replica topology. You can look at its log to check it
 - once all tservers are created, the `yb_servers()` topology is displayed

2. check the cluster on the console http://localhost:7000/tablet-servers

3. see demo app logs like `docker logs yb-lab_yb-demo_1`. It runs on thread for each line in `client/ybdemo.sql` connecting with settings in `hikari.properties`. The default displays info about the currently connected session, every 1 second. 

In order to play with High Availability, look at where a thread is connected, stop that node, like with `docker stop yb-tserver-6` and check application continuity from the yb-lab_yb-demo_n logs. And the console to see the new leader election. Restart the node, and see how it re-balances.

you can go to any node with something like `docker exec -it yb-lab_yb-demo_1 bash` and use `ysqlsh` like you would use `psql`. You can also connect to a node (the 5433 port from yb-tserver-0 is redirected from localhost:5433, yb-tserver-2 from 5434...)



