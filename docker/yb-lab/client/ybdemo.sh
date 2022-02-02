cd $(dirname $0)
curl -Ls https://github.com/FranckPachot/ybdemo/releases/download/v0.0.1/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar > YBDemo.jar
case $1 in 
init)
ysqlsh -h yb-tserver-0 -e <<'SQL'
drop database if not exists demo;
create database demo;
\l
\c demo
create table if not exists demo(id bigint generated always as identity, ts timestamptz default clock_timestamp(), message text, primary key(id hash));
insert into demo(message) select format('Message #%s',generate_series(1,1000));
SQL
  ;;
*)
   java -jar YBDemo.jar < ./ybdemo.sql 
  ;;
esac
