# list of tags you want to build for
# can be any yugabytedb/yugabyte tag
tags="latest"

[ -z "$tags" ] && tags=$(
curl -Ls "https://registry.hub.docker.com/v2/repositories/yugabytedb/yugabyte/tags?page_size=999" | 
jq -r '."results"[]["name"]' | 
sort -V 
)
for tag in $tags
do
 echo $tag $tag
 # add "preview" tag if it is the latest preview
 [ "$tag" == "$( echo "$tags" | awk -F. '!/latest/ && ($2/2)==preview/2+int($2/2){tag=$0}END{print tag}' preview=1)" ] &&
 echo preview $tag
 # add "stable" tag if it is the latest stable
 [ "$tag" == "$( echo "$tags" | awk -F. '!/latest/ && ($2/2)==preview/2+int($2/2){tag=$0}END{print tag}' preview=0)" ] &&
 echo stable $tag
done | tail -1 | while read target from
do

cat > yb-cmd.sh << 'CAT'
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
CAT

cat > yb-healthcheck.sh << 'CAT'
postgres/bin/pg_isready -h ${PGHOST:-$(hostname)}
CAT

cat > yb-create-if-not-exists.sh << 'CAT'
POSTGRES_USER="${POSTGRES_USER:-yugabyte}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-yugabyte}"
POSTGRES_DB="${POSTGRES_DB:-$POSTGRES_USER}"
PGPASSWORD=yugabyte ysqlsh -e -h "$(hostname)" -c "
alter user postgres password '${POSTGRES_PASSWORD}'
" -c "
alter user yugabyte password '${POSTGRES_PASSWORD}';
" -c "
create user ${POSTGRES_USER} password '${POSTGRES_PASSWORD}'
" -c "
create database ${POSTGRES_DB}
" 
echo '\c' | PGPASSWORD=${POSTGRES_PASSWORD} ysqlsh -h "$(hostname)" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 && date > yb-create.done
CAT

cat > Dockerfile << DOCKERFILE
FROM yugabytedb/yugabyte:$from
ENV YB_MASTER ""
ENV YB_RF     "1"
WORKDIR /home/yugabyte
ADD  yb-cmd.sh .
ADD  yb-healthcheck.sh .
ADD  yb-create-if-not-exists.sh .
VOLUME /data
HEALTHCHECK --interval=1s --timeout=1s --start-period=15s --retries=3 CMD [ -f yb-create.done ] && sh yb-healthcheck.sh
CMD sh yb-cmd.sh /data 7100 \$YB_MASTER
DOCKERFILE

# build the image
docker build -t pachot/yb:$target . || exit

# test the image
for PGUSER in "yugabyte" "usr" ; do
for PGDATABASE in "yugabyte" "dbs" ; do
for PGPASSWORD in "yugabyte" "pwd" ; do
container=$(docker run --rm -d -e POSTGRES_USER="$PGUSER" -e POSTGRES_DB="$PGDATABASE" -e POSTGRES_PASSWORD="$PGPASSWORD" -p 5433:5433 pachot/yb:$target) || exit
until docker inspect $container | grep '"Status": "healthy"' ; do sleep 0.1 ; done
export PGUSER PGDATABASE PGPASSWORD
psql -h localhost -p 5433 -v ON_ERROR_STOP=1 <<SQL
\l
\du
SQL
[ $? -gt 0 ] && exit
docker stop $container
done
echo "=== ok"
done ; done ; done

