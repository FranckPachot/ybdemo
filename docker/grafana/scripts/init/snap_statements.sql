\pset pager off

drop table if exists ybwr_pg_stat_statements cascade;

create table if not exists ybwr_pg_stat_statements as
 select now() as ts,* from pg_stat_statements where null is not null;

with lastones as (insert into ybwr_pg_stat_statements 
 select now() as ts,* from pg_stat_statements
 returning queryid)
 select ts,calls, mean_time,query, pg_stat_statements_reset() as "."
  from ybwr_pg_stat_statements
  where queryid in (select queryid from lastones)
  and ts > now() - interval '30 seconds'
 order by ts, query;

\watch 15
\q

