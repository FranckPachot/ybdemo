#
# when POSTGRES_PASSWORD is not defined, disable authentication (this is different from PostgreSQL image where POSTGRES_PASSWORD is mandatory
if [ -z "$POSTGRES_PASSWORD" ] ; then ysql_enable_auth=false ; else ysql_enable_auth=true ; fi
# by default, this is the only master
export masters="$(hostname)":"$2" 
[ -n "$3" ] &&  export masters="$3":"$2"
# todo if $YB_MASTER is set then find all other masters then add them and decide to run a new one
(
/home/yugabyte/bin/yb-master --fs_data_dirs="$1"   \
 --master_addresses="$masters" --replication_factor=1 \
 --default_memory_limit_to_ram_ratio=0.30
) &
(
/home/yugabyte/bin/yb-tserver --fs_data_dirs="$1"  \
 --tserver_master_addrs="$masters" \
 --ysql_enable_auth="$ysql_enable_auth" \
 --default_memory_limit_to_ram_ratio=0.30 
) &
until sh /home/yugabyte/yb-healthcheck.sh ; do sleep 0.1 ; done | uniq
sh /home/yugabyte/yb-create-if-not-exists.sh
tail -F "$1"/yb-data/*/logs/yb-*.INFO | grep -v " DEBUG:"
