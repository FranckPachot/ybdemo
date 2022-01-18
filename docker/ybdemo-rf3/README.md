run `gen-yb-docker-compose.sh` to generate a `docker-compose.yaml` in the current directory, to create a cluster with the settings are defined in the generation script

check the cluster on http://localhost:7000/tablet-servers

see demo app logs like `docker logs ybdemo-rf3_yb-demo_1`. It runs on thread for each line in `client/ybdemo.sql` connecting with settings in `hikari.properties`. The default displays info about the currently connected session, every 1 second.

Look at where a thread is connected, stop that node, like with `docker stop yb-tserver-6` and check application continuity, new leader election in the console, new connection from the pool. Restart the node, and see how it re-balances.
