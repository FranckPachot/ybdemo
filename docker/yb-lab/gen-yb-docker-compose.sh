
####################################################################
# creates a docker-compose.yaml to build a RF=$replication_factor 
# cluster with $number_of_tservers nodes in total,
# distributed to the clouds / regions / zones defined by the list 
# (to simulate multi-cloud, multi-region, multi-AZ cluster)
####################################################################


# this is a lab, I set all new and beta features and low memory
flags="--ysql_beta_feature_tablespace_alteration=true --ysql_enable_packed_row=true --ysql_beta_features=true --yb_enable_read_committed_isolation=true --default_memory_limit_to_ram_ratio=0.20"

case $1 in

rf1)
# example RF-1 two nodes
replication_factor=1
list_of_clouds="cloud"
list_of_regions="region"
list_of_zones="zone1 zone2 zone3"
number_of_tservers=2
read_replica_regexp=""
demo=0
;;

rf3)
# example RF-1 two nodes
replication_factor=3
list_of_clouds="cloud"
list_of_regions="region"
list_of_zones="zone"
number_of_tservers=3
read_replica_regexp=""
demo=0
;;

minimal)
# example RF-1 one nodes
replication_factor=1
list_of_clouds="cloud"
list_of_regions="region"
list_of_zones="zone1 zone2 zone3"
number_of_tservers=1
read_replica_regexp=""
demo=0
;;

aws)
# example Multi-AZ two node per AZ
replication_factor=3
list_of_clouds="aws"
list_of_regions="eu-west-1"
list_of_zones="eu-west-1a eu-west-1b eu-west-1c"
number_of_tservers=6
read_replica_regexp=""
demo=1
;;

rr) 
# example cloud/region/zone + read replicas
replication_factor=3
list_of_clouds="cloud1 cloud2"
list_of_regions="region1 region2"
list_of_zones="zone1 zone2"
number_of_tservers=8
read_replica_regexp="cloud2.region2.zone[1-2]"
demo=1
;;

ss) 
# example multi-region in the solar system ;)
replication_factor=1
list_of_clouds="star"
list_of_regions="earth moon mars"
list_of_zones="base"
number_of_tservers=3
read_replica_regexp=""
demo=0
;;

geo) 
# example multi-region in the solar system ;)
replication_factor=1
list_of_clouds="cloud"
list_of_regions="eu-west us-east us-west"
list_of_zones="az1 az2 az3"
number_of_tservers=15
read_replica_regexp=""
demo=0
;;

*)
# example cloud/region/zone
replication_factor=3
list_of_clouds="cloud1 cloud2"
list_of_regions="region1 region2"
list_of_zones="zone1 zone2"
number_of_tservers=8
read_replica_regexp=""
demo=1
;;

esac

number_of_masters=$replication_factor

# this gets the latest tag for stable release (when preview=0) or preview release (preview=1):
tag=$( curl -Ls "https:""//registry.hub.docker.com/v2/repositories/yugabytedb/yugabyte/tags?page_size=999" | jq -r '."results"[]["name"]' | sort -rV | awk -F. '!/latest/ && ($2/2)==preview/2+int($2/2){print;exit}' preview=1 )
# if nothing (not having curl, jq, ...) take the latest
tag="${tag:-latest}"


{

cat <<CAT

version: '2'

services:

# demos with connect / read / write workloads

  yb-demo-connect:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","connect","9"]
      deploy:
          replicas: $demo
          restart_policy:
             condition: on-failure

  yb-demo-read:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","read","1"]
      deploy:
          replicas: $demo
          restart_policy:
             condition: on-failure

  yb-demo-write:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","insert","1"]
      deploy:
          replicas: $demo
          restart_policy:
             condition: on-failure

# table create and other initialization for demos

  yb-demo-init:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","init"]
      deploy:
          replicas: $demo
          restart_policy:
             condition: on-failure

  yb-demo-metrics:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: ["bash","client/ybdemo.sh","ybwr"]
      deploy:
          restart_policy:
             condition: on-failure

  sqlpad:
      image: sqlpad/sqlpad:5
      hostname: 'sqlpad'
      ports:
          - '3000:3000'
      depends_on:
          - yb-tserver-1
      volumes:
          - /var/tmp/sqlpad:/var/lib/sqlpad
      environment:
          SQLPAD_AUTH_DISABLED: true
          SQLPAD_ADMIN: 'admin'
          SQLPAD_ADMIN_PASSWORD: 'admin'
          SQLPAD_APP_LOG_LEVEL: debug
          SQLPAD_WEB_LOG_LEVEL: warn
          SQLPAD_SEED_DATA_PATH: /etc/sqlpad/seed-data
          SQLPAD_CONNECTIONS__yb-tserver-0__name: yb-tserver-0
          SQLPAD_CONNECTIONS__yb-tserver-0__driver: postgres
          SQLPAD_CONNECTIONS__yb-tserver-0__host: yb-tserver-0
          SQLPAD_CONNECTIONS__yb-tserver-0__port: 5433
          SQLPAD_CONNECTIONS__yb-tserver-0__database: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-0__username: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-0__password: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-0__multiStatementTransactionEnabled: 'true'
          SQLPAD_CONNECTIONS__yb-tserver-0__idleTimeoutSeconds: 86400
          SQLPAD_CONNECTIONS__yb-tserver-1__name: yb-tserver-1
          SQLPAD_CONNECTIONS__yb-tserver-1__driver: postgres
          SQLPAD_CONNECTIONS__yb-tserver-1__host: yb-tserver-1
          SQLPAD_CONNECTIONS__yb-tserver-1__port: 5433
          SQLPAD_CONNECTIONS__yb-tserver-1__database: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-1__username: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-1__password: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-1__multiStatementTransactionEnabled: 'true'
          SQLPAD_CONNECTIONS__yb-tserver-1__idleTimeoutSeconds: 86400
          SQLPAD_CONNECTIONS__yb-tserver-2__name: yb-tserver-2
          SQLPAD_CONNECTIONS__yb-tserver-2__driver: postgres
          SQLPAD_CONNECTIONS__yb-tserver-2__host: yb-tserver-2
          SQLPAD_CONNECTIONS__yb-tserver-2__port: 5433
          SQLPAD_CONNECTIONS__yb-tserver-2__database: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-2__username: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-2__password: yugabyte
          SQLPAD_CONNECTIONS__yb-tserver-2__multiStatementTransactionEnabled: 'true'
          SQLPAD_CONNECTIONS__yb-tserver-2__idleTimeoutSeconds: 86400

# yb-master and yb-tservers

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
      volumes:
          - ./client:/home/yugabyte/client
      container_name: yb-master-$master
      hostname: yb-master-$master.$zone.$region.$cloud
      command: bash -c "
                rm -rf /tmp/.yb* ; 
                /home/yugabyte/bin/yb-master $flags
                --fs_data_dirs=/home/yugabyte/data
                --placement_cloud=$cloud
                --placement_region=$region
                --placement_zone=$zone
                --rpc_bind_addresses=yb-master-$master.$zone.$region.$cloud:7100
                --master_addresses=$master_addresses
                --replication_factor=$replication_factor
                --rpc_connection_timeout_ms=15000
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
### This doesn't work
placement_uuid="--placement_uuid=rw"
tserver_rw="
$tserver_rw
$cloud.$region.$zone
"
### then replace with no placement uuid
placement_uuid=""
tserver_rw=""
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
      volumes:
          - ./client:/home/yugabyte/client
      container_name: yb-tserver-$tserver
      hostname: yb-tserver-$tserver.$zone.$region.$cloud
      command: bash -c "
                rm -rf /tmp/.yb* ; 
                /home/yugabyte/bin/yb-tserver $flags
                --placement_cloud=$cloud 
                --placement_region=$region 
                --placement_zone=$zone 
                --enable_ysql=true 
                --fs_data_dirs=/home/yugabyte/data 
                --rpc_bind_addresses=yb-tserver-$tserver.$zone.$region.$cloud:9100 
                --tserver_master_addrs=$master_addresses 
                --ysql_num_shards_per_tserver=2
                --rpc_connection_timeout_ms=15000
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

cat <<CAT
# adding a template to add more replicas (in the latest zone)

  yb-tserver-n:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
      command: bash -c "
                /home/yugabyte/bin/yb-tserver $flags
                --placement_cloud=$cloud 
                --placement_region=$region 
                --placement_zone=$zone 
                --enable_ysql=true 
                --fs_data_dirs=/home/yugabyte/data 
                --tserver_master_addrs=$master_addresses 
                --ysql_num_shards_per_tserver=2
                --rpc_connection_timeout_ms=15000
                $placement_uuid
                "
      deploy:
          replicas: 0
      depends_on:
      - yb-master-$(( $number_of_masters - 1))
CAT

[ -n "$read_replica_regexp" ] && {
cat <<CAT


# ephemeral container to tag read replicas if defined

  cluster-config:
      image: yugabytedb/yugabyte:${tag}
      volumes:
          - ./client:/home/yugabyte/client
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
cp docker-compose.yaml "example-docker-compose-${1:-ybdemo}.yaml"



echo "$*" | grep "generate-only" || {

docker-compose down
docker-compose up -d
sleep 3 
until docker exec -it yb-tserver-0 ysqlsh -h yb-tserver-0 -c 'select  cloud,region,zone,host,port,node_type,public_ip from yb_servers() order by 1,2,3,6' | grep -B $(( $number_of_tservers + 5)) "$number_of_tservers rows" ; do sleep 1 ; done 
echo "
Run to following to see it running:     docker-compose logs -f
change docker-compose.yaml and reload:  docker-compose up -d

"


echo

}

# set aliases (when sourced)
{

for i in $( docker-compose ps | awk 'NR>1{print $1}' )
do
alias $i="\
docker exec -it $i bash \
" 
done

alias ysqlsh="\
docker exec -it yb-tserver-0 ysqlsh -h yb-tserver-0 \
" 

alias yb-admin="\
docker exec -it yb-master-0 /home/yugabyte/bin/yb-admin   \
 --master_addresses $(echo yb-master-{0..2}:7100|tr ' ' ,)\
"

alias yb-lab="
curl -Ls http://localhost:7000//api/v1/cluster-config | jq
yb-admin list_all_masters

ysqlsh -h yb-tserver-0 -c '
select version();
' -c '
select * from yb_servers() order by 1,2,3,6
'
cd '$PWD' && docker-compose -f ./docker-compose.yaml ps
"

}


