docker-compose rm

####################################################################
# creates a docker-compose.yaml to build a RF=$replication_factor 
# cluster with $number_of_tservers nodes in total,
# distributed to the clouds / regions / zones defined by the list 
# (to simulate multi-cloud, multi-region, multi-AZ cluster)
####################################################################


replication_factor=1
list_of_clouds="cloud"
list_of_regions="region"
list_of_zones="zone1 zone2 zone3"
number_of_tservers=2

replication_factor=3
list_of_clouds="cloud1 cloud2"
list_of_regions="region1 region2"
list_of_zones="zone1 zone2"
number_of_tservers=8


number_of_masters=$replication_factor


{

cat <<'CAT'

version: '2'

services:

  yb-demo:
      image: yugabytedb/yugabyte:latest
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh"]
      deploy:
          replicas: 3
      depends_on:
      - yb-tserver-0

CAT

# counts the number of master and tserver generated
master=0
tserver=0
# the masters must know the host:port of their peers
master_addresses=$(for i in $(seq 0 $(( $number_of_masters - 1)) ) ; do echo "yb-master-$i:7100" ; done | paste -sd,)

for node in $(seq 1 $number_of_tservers)
do
for zone in $list_of_zones 
do
for region in $list_of_regions 
do 
for cloud in $list_of_clouds 
do

# generate master service
[ $master -le $(( $number_of_masters - 1 )) ] && {

cat <<CAT

  yb-master-$master:
      image: yugabytedb/yugabyte:latest
      container_name: yb-master-$master
      hostname: yb-master-$master
      command: [ "/home/yugabyte/bin/yb-master",
                "--fs_data_dirs=/home/yugabyte/data",
                "--placement_cloud=$cloud",
                "--placement_region=$region",
                "--placement_zone=$zone",
                "--rpc_bind_addresses=yb-master-$master:7100",
                "--master_addresses=$master_addresses",
                "--replication_factor=$replication_factor"]
      ports:
      - "$((7000 + $master)):7000"
$master_depends
CAT

# the currently created is a dependency for the next one
master_depends="\
      depends_on:
      - yb-master-$master
"

}

# generate tserver service
[ $tserver -le $(( $number_of_tservers - 1 )) ] && { 

cat <<CAT

  yb-tserver-$tserver:
      image: yugabytedb/yugabyte:latest
      container_name: yb-tserver-$tserver
      hostname: yb-tserver-$tserver
      command: [ "/home/yugabyte/bin/yb-tserver",
                "--placement_cloud=$cloud",
                "--placement_region=$region",
                "--placement_zone=$zone",
                "--enable_ysql=true",
                "--fs_data_dirs=/home/yugabyte/data",
                "--rpc_bind_addresses=yb-tserver-$tserver:9100",
                "--tserver_master_addrs=$master_addresses",
                "--replication_factor=$replication_factor"]
      ports:
      - "$(( 9000 + $tserver)):9000"
      - "$(( 5433 + $tserver)):5433"
      depends_on:
      - yb-master-$(( $number_of_masters - 1))

CAT

}

master=$(($master+1))
tserver=$(($tserver+1))

done
done
done
done

} | tee docker-compose.yaml

docker-compose up -d
sleep 3 
until docker exec -it yb-tserver-0 ysqlsh -c 'select  cloud,region,zone,host,port from yb_servers() order by cloud,region,zone,host' | grep -B $(( $number_of_tservers + 5)) "$number_of_tservers rows" ; do sleep 1 ; done 

exit







function placement(){
case $1 in
 0) echo '  "--placement_cloud=cloud1",  "--placement_region=region1",  "--placement_zone=zone1",'  ;;
 1) echo '  "--placement_cloud=cloud1",  "--placement_region=region1",  "--placement_zone=zone2",'  ;;
 2) echo '  "--placement_cloud=cloud1",  "--placement_region=region2",  "--placement_zone=zone1",'  ;;
 3) echo '  "--placement_cloud=cloud1",  "--placement_region=region2",  "--placement_zone=zone2",'  ;;
 4) echo '  "--placement_cloud=cloud2",  "--placement_region=region1",  "--placement_zone=zone1",'  ;;
 5) echo '  "--placement_cloud=cloud2",  "--placement_region=region1",  "--placement_zone=zone2",'  ;;
 6) echo '  "--placement_cloud=cloud2",  "--placement_region=region2",  "--placement_zone=zone1",'  ;;
 7) echo '  "--placement_cloud=cloud2",  "--placement_region=region2",  "--placement_zone=zone2",'  ;;
esac
}
docker-compose rm
{
cat <<'CAT'
version: '2'
services:
CAT
for i in {0..2}
do 
cat <<CAT
  yb-master-${i}:
      image: yugabytedb/yugabyte:latest
      container_name: yb-master-${i}
      hostname: yb-master-${i}
      command: [ "/home/yugabyte/bin/yb-master",
                "--fs_data_dirs=/home/yugabyte/data",
                $( placement ${i} )
                "--master_addresses=$(echo 'yb-master-'{0..2}:7100 | tr ' ' ',')",
                "--replication_factor=3"]
      ports:
      - "700${i}:7000"
CAT
done
for i in {0..7}
do 
cat <<CAT
  yb-tserver-${i}:
      image: yugabytedb/yugabyte:latest
      container_name: yb-tserver-${i}
      hostname: yb-tserver-${i}
      command: [ "/home/yugabyte/bin/yb-tserver",
                "--fs_data_dirs=/home/yugabyte/data",
                $( placement ${i} )
                "--enable_ysql=true",
                "--tserver_master_addrs=$(echo 'yb-master-'{0..2}:7100 | tr ' ' ',')",
                "--replication_factor=3"]
      ports:
      - "900${i}:9000"
      #- "1300${i}:13000"
      - "543${i}:5433"
      depends_on:
      - yb-master-0
CAT
done
exit
cat <<'CAT'
  demo:
      image: yugabytedb/yugabyte:latest
      container_name: demo
      command: [ "/home/yugabyte/bin/yugabyted",
                "demo",
                "connect"]
CAT
} | tee docker-compose.yaml
docker-compose up

exit

for N in 1 2
do docker run -d --rm --name yugabyte$N --net=universe --hostname=yugabyte$N -p700$N:7000 \
  yugabytedb/yugabyte:latest bin/yugabyted start \
  --base_dir=/tmp/ybd \
  --listen=yugabyte$N \
  --join=yugabyte \
  --master_flags "ysql_num_shards_per_tserver=4" \
  --tserver_flags "ysql_num_shards_per_tserver=4,follower_unavailable_considered_failed_sec=30" \
  --daemon=false
done

####
cluster=demo
join=""
set -x
for i in {0..4}
do
docker run -d --rm --name yb${cluster}${i} --hostname yb${cluster}${i} -p 700${i}:7000 -p 900${i}:9000 -p 1300${i}:13000 -p 543${i}:5433 -p 710${i}:7100 -p 910${i}:9100  yugabytedb/yugabyte:latest /home/yugabyte/bin/yugabyted start $join --base_dir=/home/data --listen=yb${cluster}${i} --daemon=false
sleep 60
join="--join=yb${cluster}0"
done
exit
for N in 1 2
do docker run -d --rm --name yugabyte$N --net=universe --hostname=yugabyte$N -p700$N:7000 \
  yugabytedb/yugabyte:latest bin/yugabyted start \
  --base_dir=/tmp/ybd \
  --listen=yugabyte$N \
  --join=yugabyte \
  --master_flags "ysql_num_shards_per_tserver=4" \
  --tserver_flags "ysql_num_shards_per_tserver=4,follower_unavailable_considered_failed_sec=30" \
  --daemon=false
done

exit
cat <<'CAT'
version: '2'
services:
CAT
join=""
for i in {0..4}
do 
cat <<CAT
  yb${i}:
      image: yugabytedb/yugabyte:latest
      container_name: yb${i}
      hostname: yb${i}
      command: [ "/usr/bin/bash",
                "-c",
                "sleep 60 ; /home/yugabyte/bin/yugabyted start $join --base_dir=/home/data --listen=yb${i} --daemon=false"]
      ports:
      - "700${i}:7000"
      - "900${i}:9000"
      - "1300${i}:13000"
      - "543${i}:5433"
CAT
[ yb${i} == "yb0" ] || cat <<CAT
      depends_on:
      - yb0
CAT
join="--join=yb0"
done
exit
cat <<'CAT'
  demo:
      image: yugabytedb/yugabyte:latest
      container_name: demo
      command: [ "/home/yugabyte/bin/yugabyted",
                "demo",
                "connect"]
CAT

exit

for N in 1 2
do docker run -d --rm --name yugabyte$N --net=universe --hostname=yugabyte$N -p700$N:7000 \
  yugabytedb/yugabyte:latest bin/yugabyted start \
  --base_dir=/tmp/ybd \
  --listen=yugabyte$N \
  --join=yugabyte \
  --master_flags "ysql_num_shards_per_tserver=4" \
  --tserver_flags "ysql_num_shards_per_tserver=4,follower_unavailable_considered_failed_sec=30" \
  --daemon=false
done
