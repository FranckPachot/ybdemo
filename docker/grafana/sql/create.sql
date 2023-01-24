
create sequence if not exists demo_sequence;
create extension if not exists orafce;

create table if not exists demo 
(id bigint primary key, value text) split into 1 tablets;


create or replace view data_dir as
select 
format('%s/tserver/data/rocksdb/table-0000%s00003000800000000000%s'
 ,replace(current_setting('data_directory'),'/pg_data','/yb-data')
 ,lpad(to_hex(oid::int),4,'0')
 ,lpad(to_hex('demo'::regclass::oid::int),4,'0')
 ) path
 from pg_database where datname=current_database()
union all
select 
format('%s/tserver/wals/table-0000%s00003000800000000000%s'
 ,replace(current_setting('data_directory'),'/pg_data','/yb-data')
 ,lpad(to_hex(oid::int),4,'0')
 ,lpad(to_hex('demo'::regclass::oid::int),4,'0')
 ) path
 from pg_database where datname=current_database()
;

create table if not exists sstfiles 
(bytes bigint, time float, name text, ts timestamptz default now());

create function sstfiles_snap() returns bigint as $$ 
declare
 n bigint;
begin
copy sstfiles(bytes,time,name) from program 'find /home/opc/10.0.0.142/var/data/pg_data/../yb-data/tserver/data/rocksdb/table-000033e8000030008000000000004485 -name "*.sst" -type f -printf  "%s\\t%T@\\t%p\\n"';
get diagnostics n = row_count;
return n;
end; 
$$ language plpgsql; 


