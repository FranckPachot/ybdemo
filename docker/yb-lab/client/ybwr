create table ybwr_snapshots(host text default '', ts timestamptz default now(),  metrics jsonb, primary key (host,ts));
create or replace function ybwr_snap() returns timestamptz as $DO$ declare i record; begin for i in (select host from yb_servers()) loop execute format($COPY$copy ybwr_snapshots(host,metrics) from program $BASH$exec 5<>/dev/tcp/%s/9000 ; awk 'BEGIN{printf "%s\t"}/[[]/{p=1}p==1{printf $0}' <&5 & printf "GET /metrics HTTP/1.0\r\n\r\n" >&5$BASH$ $COPY$,i.host,i.host); end loop; return now(); end; $DO$ language plpgsql;
create or replace view ybwr_report as
select value,round(value/seconds) rate,host,tablet_id,table_name,metric_name,ts,relative_snap_id
from (
select ts,host,metric_name,table_name,tablet_id
,metric_value-lead(metric_value)over(partition by host,table_name,tablet_id,metric_name order by ts desc) as value
,extract(epoch from ts-lead(ts)over(partition by host,table_name,tablet_id,metric_name order by ts desc)) as seconds
,rank()over(partition by host,table_name,tablet_id,metric_name order by ts desc) as relative_snap_id
from (
select host,ts
 ,jsonb_array_elements(metrics)->>'type' as type
 ,jsonb_array_elements(metrics)->>'id'   as tablet_id
 ,jsonb_array_elements(metrics)->'attributes'->>'table_name'  as table_name
 ,jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'name' as metric_name
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'value')::bigint as metric_value
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'total_sum')::bigint as metric_sum
 ,(jsonb_array_elements(jsonb_array_elements(metrics)->'metrics')->>'total_sum')::bigint as metric_count
from ybwr_snapshots
) tablets
) tablets_delta where value>0;
create or replace view ybwr_last as select * from ybwr_report where relative_snap_id=1;
select ybwr_snap();
select ybwr_snap();
select value,rate,host,tablet_id,table_name,metric_name from ybwr_last order by ts desc,value desc,host,metric_name,table_name,tablet_id;
