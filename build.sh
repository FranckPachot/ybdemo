while sleep 1 
do
[ src/main/java/YBDemo.java -nt $0 ] && {
mvn package && {
java -jar /home/opc/ybdemo/target/YBDemo-0.0.1-SNAPSHOT-jar-with-dependencies.jar <<'SQL'
drop table if exists demo; 
create table if not exists demo as select 0 as v;
update demo set v=v+1 returning v+1;
update demo set v=v+1 returning v+1;
update demo set v=v+1 returning v+1;
update demo set v=v+1 returning v+1;
update demo set v=v+1 returning v+1;
update demo set v=v+1 returning v+1;
SQL
echo "=== return: $?" > /dev/stderr
} | head -10 # I'm more interrested by the errors
touch $0
}
done
