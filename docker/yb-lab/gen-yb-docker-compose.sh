docker-compose down

####################################################################
# creates a docker-compose.yaml to build a RF=$replication_factor 
# cluster with $number_of_tservers nodes in total,
# distributed to the clouds / regions / zones defined by the list 
# (to simulate multi-cloud, multi-region, multi-AZ cluster)
####################################################################


# example RF-1 two nodes
replication_factor=1
list_of_clouds="cloud"
list_of_regions="region"
list_of_zones="zone1 zone2 zone3"
read_replica_regexp=""

# example Multi-AZ two node per AZ
replication_factor=3
list_of_clouds="aws"
list_of_regions="eu-west-1"
list_of_zones="eu-west-1a eu-west-1b eu-west-1c"
number_of_tservers=6
read_replica_regexp=""

# example cloud/region/zone + read replicas
replication_factor=3
list_of_clouds="cloud1 cloud2"
list_of_regions="region1 region2"
list_of_zones="zone1 zone2"
number_of_tservers=4
#read_replica_regexp="cloud2.region2.zone[1-2]"

number_of_masters=$replication_factor

#tag=2.11.1.0-b305
tag=latest

{

cat <<CAT

version: '2'

services:

  yb-demo-connect:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","connect","3"]
      deploy:
          replicas: 3
          restart_policy:
             condition: on-failure
      depends_on:
      - yb-tserver-$(( $replication_factor - 1))

  yb-demo-read:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","read","1"]
      deploy:
          replicas: 1
          restart_policy:
             condition: on-failure
      depends_on:
      - yb-tserver-$(( $replication_factor - 1))

  yb-demo-write:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","write","1"]
      deploy:
          replicas: 1
          restart_policy:
             condition: on-failure
      depends_on:
      - yb-tserver-$(( $replication_factor - 1))

  yb-demo-init:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","init"]
      depends_on:
      - yb-tserver-$(( $replication_factor - 1))

CAT

# counts the number of master and tserver generated
master=0
tserver=0
# the masters must know the host:port of their peers
master_addresses=$(for i in $(seq 0 $(( $number_of_masters - 1)) ) ; do echo "yb-master-$i:7100" ; done | tr '\n' ','|rev|cut -c2-|rev)

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
      image: yugabytedb/yugabyte:${tag}
      container_name: yb-master-$master
      hostname: yb-master-$master
      command: bash -c "
                rm -rf /tmp/.yb* ; 
                /home/yugabyte/bin/yb-master 
                --fs_data_dirs=/home/yugabyte/data
                --placement_cloud=$cloud
                --placement_region=$region
                --placement_zone=$zone
                --rpc_bind_addresses=yb-master-$master:7100
                --master_addresses=$master_addresses
                --replication_factor=$replication_factor
                "
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

[ -n "$read_replica_regexp" ] && {
# default is primary cluster (read write in sync)
placement_uuid="--placement_uuid=rw"
tserver_rw="
$tserver_rw
$cloud.$region.$zone
"
# except if in read replica regexp pattern
echo "read replica $cloud.$region.$zone" | grep -E "^read replica $read_replica_regexp$" >&2 && {
placement_uuid="--placement_uuid=ro"
tserver_ro="
$tserver_ro
$cloud.$region.$zone:1
"
}
}

cat <<CAT

  yb-tserver-$tserver:
      image: yugabytedb/yugabyte:${tag}
      container_name: yb-tserver-$tserver
      hostname: yb-tserver-$tserver
      command: bash -c "
                rm -rf /tmp/.yb* ; 
                /home/yugabyte/bin/yb-tserver 
                --placement_cloud=$cloud 
                --placement_region=$region 
                --placement_zone=$zone 
                --enable_ysql=true 
                --fs_data_dirs=/home/yugabyte/data 
                --rpc_bind_addresses=yb-tserver-$tserver:9100 
                --tserver_master_addrs=$master_addresses 
                --replication_factor=$replication_factor 
                -yb_num_shards_per_tserver=2
                $placement_uuid
                "
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

[ -n "$read_replica_regexp" ] && {
cat <<CAT
  cluster-config:
      image: yugabytedb/yugabyte:${tag}
      command: bash -c "
                /home/yugabyte/bin/yb-admin --master_addresses $master_addresses
                modify_placement_info
                $(echo "$tserver_rw" | sort -u | paste -sd, | sed -e 's/^,//' )
                $replication_factor
                rw ;
                /home/yugabyte/bin/yb-admin 
                --master_addresses $master_addresses
                add_read_replica_placement_info
                $(echo "$tserver_ro" | sort -u | paste -sd, | sed -e 's/^,//' )
                1
                ro;
                curl -qs http://yb-master-0:7000/cluster-config?raw
                "
$master_depends
CAT
}

} | tee docker-compose.yaml

docker-compose up -d
sleep 3 
until docker exec -it yb-tserver-0 ysqlsh -h yb-tserver-0 -c 'select  cloud,region,zone,host,port,node_type,public_ip from yb_servers() order by 1,2,3,6' | grep -B $(( $number_of_tservers + 5)) "$number_of_tservers rows" ; do sleep 1 ; done 

echo

exit

