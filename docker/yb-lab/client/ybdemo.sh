cd $(dirname $0)
curl -Ls https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar > YBDemo.jar
case $1 in 
init)
until ysqlsh -h yb-tserver-0 -e <<'SQL'
create table if not exists demo(id bigint generated always as identity, ts timestamptz default clock_timestamp(), message text, primary key(id hash));
insert into demo(message) select format('Message #%s',generate_series(1,1000));
SQL
do sleep 1; done
  ;;
read)
   {
   echo "
   select format('Rows inserted in the last minute: %s',to_char(count(*),'999999999')) from demo where ts > clock_timestamp() - interval '1 minute';
   "
   } | java -jar YBDemo.jar
  ;;
write)
   {
   echo "
   select format('Rows inserted in the last minute: %s',to_char(count(*),'999999999')) from demo where ts > clock_timestamp() - interval '1 minute';
   "
   for i in {1..1} ; do echo "
   insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
   " ; done 
   } | java -jar YBDemo.jar
  ;;
*)
   for i in {1..3} ; do echo "execute ybdemo(1000);" ; done | java -jar YBDemo.jar
  ;;
esac
