\q

create extension if not exists orafce;
create sequence if not exists demo_sequence;

create table if not exists demo 
(id bigint primary key, value text) split into 1 tablets;


\q

create or replace view table_data_dir as
SELECT n.nspname, c.relname , c.relkind
 , format('%s/tserver/%s/table-0000%s00003000800000000000%s'
 ,replace(current_setting('data_directory'),'/pg_data','/yb-data')
 , dir
 ,(select to_hex(oid::int) from pg_database where datname=current_database())
 ,lpad(to_hex(c.oid::int),4,'0')
 ) path
FROM 
(select 'data/rocksdb' as dir union select 'wals' as dir) dirs,
pg_catalog.pg_class c
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','i')
      AND n.nspname <> 'pg_catalog'
      AND n.nspname <> 'information_schema'
      AND n.nspname !~ '^pg_toast'
  AND pg_catalog.pg_table_is_visible(c.oid)
;

create table if not exists sstfiles 
(bytes bigint, time float, name text, ts timestamptz default now());

create or replace function sstfiles_snap(path text default '/', regex text default '.*') returns bigint as $$ 
declare
 n bigint;
begin
 execute 'copy sstfiles(bytes,time,name) from program ''
 [ -d "'||path||'" ] && find "'||path||'" -regextype posix-egrep -regex "'||regex||'" -type f -printf  "%s\\t%T@\\t%p\\n"
 '''; 
get diagnostics n = row_count;
return n;
end; 
$$ language plpgsql; 
truncate sstfiles;

select sstfiles_snap('/root/var/data/yb-data','.*/(wal-[0-9]+|[0-9]+[.]sblock[.]0)');
select name from sstfiles;

select * from table_data_dir, lateral(
select sstfiles_snap(path,'.*/(wal-[0-9]+|[0-9]+[.]sblock[.]0)') 
) as copy;


select sstfiles_snap('/root/var/data/yb-data/tserver/data/rocksdb/table-000033e800003000800000000000427c','.*/(wal-[0-9]*)|(.*[.]sst[.]block[.0])');
select * from sstfiles;


select ts as "time" -- $__time(ts)
,bytes
, max(to_char(to_timestamp(time),'hh24:mi:ss'))over(partition by name)||' '||regexp_replace(name,'${data_dir:raw}','') 
from sstfiles 



where name like '${data_dir:raw}/%'
where $__timeFilter(ts) and name like '${data_dir:raw}/%'
--and  sstfiles.name not like '%.intents/%' and sstfiles.name like '%.sst.sblock.0%'
and (name like '%/rocksdb/%sst.sblock.0' or name like '%/wals/%') and name not like '%.intents/%' and name not like 'xxx'
order by time,name asc


