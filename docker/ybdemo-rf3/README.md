run `gen-yb-docker-compose.sh` to create a cluster (the settings are defined in the script)

check the cluster on http://localhost:7000/tablet-servers

see demo app logs like `docker logs ybdemo-rf3_yb-demo_1`

look at where a thread is connected

stop that node `docker stop yb-tserver-6`

see it continuing

```
 docker logs ybdemo-rf3_yb-demo_2 | grep Thread-5
 docker exec -it ybdemo-rf3_yb-demo_2 host 192.168.96.7
 docker stop yb-tserver-6

```
