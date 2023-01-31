\pset pager off

drop table if exists ybwr_files cascade;

create or replace view ybwr_tables_with_data_dir as
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

create table if not exists ybwr_files (
server text default inet_server_addr(), bytes bigint, time float, filename text, ts timestamptz default now()
,primary key(ts asc, filename asc)
);

create or replace function ybwr_files_snap(path text default '/', regex text default '.*') returns bigint as $$ 
declare
 n bigint;
begin
 execute 'copy ybwr_files(bytes,time,filename) from program ''
 if [ -d "'||path||'" ] ; then
 find "'||path||'" -regextype posix-egrep -regex "'||regex||'" -type f -printf  "%s\\t%T@\\t%p\\n"
  else true ; fi
 '''; 
get diagnostics n = row_count;
return n;
end; 
$$ language plpgsql; 

truncate ybwr_files;

create view ybwr_files_history as 
select ts,relname,bytes,pg_size_pretty(bytes)
,max(to_char(to_timestamp(time),'hh24:mi:ss'))over(partition by filename)||' '||replace(filename,path,'') as file
from ybwr_files f join ybwr_tables_with_data_dir t on f.filename||'%' like t.path||'%'
order by 1,2,3;

with get_a_snap as (
 select * from ybwr_tables_with_data_dir, lateral(
 select ybwr_files_snap(path,'.*/(wal-[0-9]+|[0-9]+[.]sst[.]sblock[.]0)') as last_snap_count
 ) as copy
)
select nspname,relname,relkind,last_snap_count,regexp_replace(path,'^.*/tserver/','') path from get_a_snap
order by last_snap_count
;

\watch 0.5

\q

