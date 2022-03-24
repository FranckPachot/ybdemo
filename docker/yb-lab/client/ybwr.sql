-- the "ybwr_snapshots" table stores snapshots of tserver metrics, gathered by "ybwr_snap", reading all endpoints known by "yb_servers()"

create table if not exists ybwr_snapshots(host text default '', ts timestamptz default now(),  metrics jsonb, primary key (host,ts));

create or replace function ybwr_snap(snaps_to_keep int default 1000) returns timestamptz as $DO$
declare i record; 
begin
delete from ybwr_snapshots where ts not in (select distinct ts from ybwr_snapshots order by ts desc limit snaps_to_keep);
for i in (select host from yb_servers()) loop 
 execute format(
  $COPY$
  copy ybwr_snapshots(host,metrics) from program
   $BASH$
   exec 5<>/dev/tcp/%s/9000 ; awk 'BEGIN{printf "%s\t"}/[[]/{in_json=1}in_json==1{printf $0}' <&5 & printf "GET /metrics HTTP/1.0\r\n\r\n" >&5
   $BASH$
  $COPY$
 ,i.host,i.host); 
end loop; 
return now(); 
end; 
$DO$ language plpgsql;

-- most metrics are cumulative and the "ybwr_report" view show the delta between two snapshots

create or replace view ybwr_report as
select value,round(value/seconds) rate,host,tablet_id,namespace_name,table_name,metric_name,ts,relative_snap_id
from (
select ts,host,metric_name,namespace_name,table_name,tablet_id
,metric_value-lead(metric_value)over(partition by host,namespace_name,table_name,tablet_id,metric_name order by ts desc) as value
,extract(epoch from ts-lead(ts)over(partition by host,namespace_name,table_name,tablet_id,metric_name order by ts desc)) as seconds
,rank()over(partition by host,namespace_name,table_name,tablet_id,metric_name order by ts desc) as relative_snap_id
,metric_value,metric_sum,metric_count
from (
select host,ts
 ,jsonb_array_elements(metrics)->>'type' as type
 ,jsonb_array_elements(metrics)->>'id'   as tablet_id
 ,jsonb_array_elements(metrics)->'attributes'->>'namespace_name'  as namespace_name
 ,jsonb_array_elements(metrics)->'attributes'->>'table_name'  as table_name
 ,jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'name' as metric_name
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'value')::bigint as metric_value
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'total_sum')::bigint as metric_sum
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'total_count')::bigint as metric_count
from ybwr_snapshots
) tablets
) tablets_delta where value>0;

-- a convenient "ybwr_last" shows the last snapshot:
create or replace view ybwr_last as select * from ybwr_report where relative_snap_id=1;

-- a convenient "ybwr_snap_and_show_tablet_load" takes a snapshot and show the metrics
create or replace view ybwr_snap_and_show_tablet_load as 
select value,rate,namespace_name,table_name,metric_name,host,tablet_id
,to_char(100*value/sum(value)over(partition by namespace_name,table_name,metric_name),'999%') as "%table"
,sum(value)over(partition by namespace_name,table_name,metric_name) as "table"
from ybwr_last , ybwr_snap()
where table_name not in ('metrics','ybwr_snapshots')
and metric_name not in ('follower_lag_ms')
order by ts desc,namespace_name,table_name,host,tablet_id,"table" desc,value desc,metric_name;

-- example:

select ybwr_snap();

-- prepare some statements to take a snap and display per table or per tables insterresting stats

create extension if not exists tablefunc;

prepare snap_table as
select * from crosstab($$select format('%s %s %s %s',namespace_name,table_name,host,tablet_id) row_name, metric_name category, value from ybwr_snap_and_show_tablet_load where name
space_name not in ('system') and metric_name in ('rocksdb_number_db_seek','rocksdb_number_db_next') order by 1,2 desc,3$$) as (row_name text, rocksdb_number_db_seek bigint, rocksdb_number_db_next bigint) ;

prepare snap_tablet as 
select * from ybwr_snap_and_show_tablet_load where namespace_name not in ('system') and metric_name in ('rows_inserted','rocksdb_number_db_seek','rocksdb_number_db_next');
execute snap_tablet;
\watch 10
