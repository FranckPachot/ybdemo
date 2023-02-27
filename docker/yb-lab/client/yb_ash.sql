drop table if exists yb_ash_plans cascade;
drop function if exists yb_ash_sample;
drop procedure if exists yb_ash_loop;
drop view if exists yb_ash_explain_top5;

create table if not exists yb_ash_plans(
 plan_hash_value text primary key, 
 samples int, running_for interval,last_plan text,last_pg_stat_activity jsonb
 );
 
create or replace function yb_ash_sample() returns int as
 $$
declare
 psa record;
 plan_xml text;
 plan_nofilter text;
 plan_md5 text;
 last_running_for interval;
 count_updated int:=0;
begin
  for psa in (select * from pg_stat_activity
   where state='active' and pid!=pg_backend_pid()) loop
   begin 
    --raise notice 'SQL %',psa.query;
    execute format('explain (format xml, costs false, buffers false) %s',psa.query) into plan_xml;
    exception when others then
     if sqlstate not like '42%' then raise warning '% % %',sqlstate,sqlerrm,psa.query; end if;
    end;
   end loop;
   if plan_xml is not null then
    --raise notice 'XML %',plan_xml;
    plan_nofilter:=regexp_replace(plan_xml,'(<Item>|<Filter>|<Index-Cond>|<Recheck-Cond>|<Join-Filter>|<Merge-Cond>|<Hash-Cond>)[^<]*(</)','\1\2','g'); 
    plan_md5=md5(plan_nofilter);
    --raise notice e'PHV   %\n%\n%',plan_md5,plan_xml,plan_nofilter;
    update yb_ash_plans set samples=samples+1 where plan_hash_value=plan_md5 returning running_for into last_running_for;
    --raise notice e'LRF   % <> %',last_running_for,clock_timestamp()-psa.query_start;
    if last_running_for is null then
      insert into yb_ash_plans(plan_hash_value,samples,running_for,last_plan,last_pg_stat_activity)
       values(plan_md5,1,clock_timestamp()-psa.query_start,plan_xml,row_to_json(psa));
      count_updated:=count_updated+1;
     else
      if last_running_for < clock_timestamp()-psa.query_start then
       update yb_ash_plans
        set running_for=clock_timestamp()-psa.query_start,
        last_plan=plan_xml, last_pg_stat_activity=row_to_json(psa)
        where plan_hash_value=plan_md5;
       count_updated:=count_updated+1;
      end if;
     end if;
   end if;
  return count_updated; 
 end;
$$ language plpgsql;

create or replace procedure yb_ash_loop(interval_sec int default 1, count_sec int default null)
 as $$
  declare n int; c int:=0 ;
  begin loop select yb_ash_sample(), pg_sleep(interval_sec) into n; 
  raise notice '% Updated statements: %',clock_timestamp(),n;
  commit;
  c:=c+1;
  exit when yb_ash_loop.count_sec is not null and c>=yb_ash_loop.count_sec;
  end loop; end;
  $$ language plpgsql;

create or replace view yb_ash_explain_top5 as 
with top_plans as (
select plan_hash_value,samples,running_for,last_pg_stat_activity->>'query' query,last_plan
 from yb_ash_plans 
order by samples desc limit 5
),
plan_relations as (
 select plan_hash_value, plan_relation
 from top_plans,         lateral (select * from (select regexp_split_to_table(last_plan,'^ *','n') plan_relation ) plan_relation where plan_relation like '<Relation-Name>%'  ) plan_relations
),
plan_aliases as (
 select plan_hash_value, plan_alias
 from top_plans,         lateral (select * from (select regexp_split_to_table(last_plan,'^ *','n') plan_alias ) plan_alias where plan_alias like '<Alias>%'  ) plan_aliases
),
plan_nodes as (
 select plan_hash_value, plan_node
 from top_plans,         lateral (select * from (select regexp_split_to_table(last_plan,'^ *','n') plan_node ) plan_nodes where plan_node like '<Node-Type>%'  ) plan_nodes
),
plan_filters as (
 select plan_hash_value, plan_filter
 from top_plans,         lateral (select * from (select regexp_split_to_table(last_plan,'^ *','n') plan_filter ) plan_filter where plan_filter like '<Filter>%'  ) plan_filters
),
plan_conds as (
 select plan_hash_value, plan_cond
 from top_plans,         lateral (select * from (select regexp_split_to_table(last_plan,'^ *','n') plan_cond ) plan_cond where plan_cond like '<%-Cond>%'  ) plan_conds
),
top_plan_elements as (
select format(
 e'/* samples: %s running for: %s \n%s\n*/\nexplain (costs off, analyze, dist, buffers)\n%s',
 samples,running_for
,json_build_object(
'tables',json_agg(distinct regexp_replace(plan_relation,'.*<Relation-Name>(.*)</Relation-Name>.*','\1')),
'aliases',json_agg(distinct regexp_replace(plan_alias,'.*<Alias>(.*)</Alias>.*','\1')),
'nodes',json_agg(distinct regexp_replace(plan_node,'.*<Node-Type>(.*)</Node-Type>.*','\1')),
'conditions',json_agg(distinct regexp_replace(plan_cond,'.*<.*-Cond>(.*)</.*-Cond>.*','\1')),
'filters',json_agg(distinct regexp_replace(plan_filter,'.*<Filter>(.*)</Filter>.*','\1'))
)
,query
)
from top_plans 
left outer join plan_relations using (plan_hash_value)
left outer join plan_aliases using (plan_hash_value)
left outer join plan_nodes using (plan_hash_value)
left outer join plan_filters using (plan_hash_value)
left outer join plan_conds using (plan_hash_value)
group by samples,running_for,query,last_plan
) select * 
from top_plan_elements
;

\pset pager off
\set echo all
select * from yb_ash_explain_top5
\gexec

-- example -- truncate table yb_ash_plans ; call yb_ash_loop(1,15); select * from yb_ash_top5;

