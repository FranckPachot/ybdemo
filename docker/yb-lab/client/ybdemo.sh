cd $(dirname $0)

# get the latest YBDemo.jar (includes postgresql and yugabytedb drivers):
#  curl -Ls https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar > YBDemo.jar

# the connection info is in client/hikari.properties

case $1 in 
init)
  # stop on error so that it is retried until sucessful
   PGCONNECT_TIMEOUT=5 ysqlsh -h yb-tserver-0 -v ON_ERROR_STOP=on -e -f /dev/stdin <<'SQL'
   drop table if exists demo;
   create table if not exists demo(id bigint generated by default as identity, ts timestamptz default clock_timestamp(), message text, u bigint default 0, i timestamptz default clock_timestamp(), primary key(id hash));
   insert into demo(message) select format('Message #%s',generate_series(1,1000));
 \! yb-admin --non_graph_characters_percentage_to_use_hexadecimal_rendering=0 -master_addresses yb-master-0:7100,yb-master-1:7100,yb-master-2:7100 -timeout_ms 1000 list_tablets ysql.yugabyte demo | awk -F"\t" '{printf "%32s %32s %32s %32s\n",$1,$4,$3,$2}'
   select format('All good :) with %s rows in "demo" table ',count(*)) from demo;
SQL
  ;;
read)
   {
   for i in $(seq 1 ${2:-1}) ; do echo "\
   with random as (select (1000*random()+1)::int id) select row_to_json(demo) from random natural left outer join demo;" ; done
   } | java -jar YBDemo.jar
  ;;
update)
   {
   for i in $(seq 1 ${2:-1}) ; do echo "\
   update demo set message=format('updated $i when connected to %s',current_setting('listen_addresses')),u=u+1, ts=clock_timestamp() where id=$i returning row_to_json(demo)" ; done 
   } | java -jar YBDemo.jar
  ;;
insert)
   {
   for i in $(seq 1 ${2:-1}) ; do echo "\
   insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo)" ; done 
   } | java -jar YBDemo.jar
  ;;
count)
   {
   echo "\
   select format('Rows inserted in the last minute: %s',to_char(count(*),'999999999')) from demo where ts > clock_timestamp() - interval '1 minute'"
   } | java -jar YBDemo.jar
  ;;
ywr_init)
  # stop on error so that it is retried until sucessful
   PGCONNECT_TIMEOUT=5 ysqlsh -h yb-tserver-0 -v ON_ERROR_STOP=on -e -f ybwr.sql
  ;;  
ywr_snap)
  # stop on error so that it is retried until sucessful
   PGCONNECT_TIMEOUT=5 ysqlsh -h yb-tserver-0 -v ON_ERROR_STOP=on -e -f /dev/stdin <<'SQL'
   select ybwr_snap();
   select row_to_json(stat) from (
   select value,rate,metric_name,host,tablet_id
   ,to_char(100*value/sum(value)over(partition by namespace_name,table_name,metric_name),'999%') as "%table"
   ,sum(value)over(partition by namespace_name,table_name,metric_name) as "table"
   from ybwr_last where table_name='demo'
   order by ts desc,"table" desc,value desc,host,metric_name,table_name,tablet_id
   ) stat;   
SQL   
  ;;    
*)
   for i in  $(seq 1 ${2:-1}) ; do echo "
   execute ybdemo(1000);
   " ; done | java -jar YBDemo.jar
  ;;
esac
