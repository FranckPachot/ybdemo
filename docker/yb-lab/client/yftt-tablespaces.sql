/*
ssh -L 5433:localhost:5433 -L 7000:localhost:7000 root@docker
[ -f ybdemo ] || git clone git@github.com:FranckPachot/ybdemo.git
cd ybdemo/docker/yb-lab 
sh gen-yb-docker-compose.sh geo 3

psql -h localhost -p 5433 -d yugabyte -U yugabyte 
--\i client/yftt-tablespaces.sql
\pset pager off
create extension pgcrypto;
*/

-- clean all
select format('drop table if exists %I.%I cascade;',schemaname,tablename) from pg_tables where tableowner='yugabyte' and tablename like 'demo%';
\gexec
select format('drop tablespace if exists %I;',spcname) from pg_tablespace where spcoptions is not null;
\gexec
\! clear
\c

---# list all servers: 
select host, cloud, region, zone from yb_servers() order by 2,3,4;

---# create a table
create table demo(id bigint primary key) split into 4 tablets;

---# create a tablespace to place RF=3 on one region (eu-west)
create tablespace "eu-west" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "eu-west", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "eu-west", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

---# alter table tablespace
alter table demo set tablespace "eu-west";

---# same in us-east
create tablespace "us-east" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

---# same in us-west
create tablespace "us-west" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

create table demo_gdpr ( 
 user_country char(2) primary key,
  user_uuid uuid default gen_random_uuid()
) partition by list(user_country);

create table demo_gdpr_eu partition of demo_gdpr
 for values in ('FR','DE','IT') tablespace "eu-west"
;

create table demo_gdpr_ch partition of demo_gdpr
 for values in ('CH') tablespace "eu-west"
;

create table demo_gdpr_ca partition of demo_gdpr
 for values in ('CA') tablespace "us-west"
;

---# the replication factor can be changed

create tablespace "rf3" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 }
    ]
} $$) ;

create tablespace "rf5" with ( replica_placement= $$
{
    "num_replicas": 5,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 }
    ]
} $$) ;


---# we can define the leader placement

create tablespace "rf5-pref-eu" with ( replica_placement= $$
{
    "num_replicas": 5,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 2 },
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 3 }
    ]
} $$) ;

alter table demo_gdpr_ch set tablespace "rf5-pref-eu";


---# region failure
select host, cloud, region, zone from yb_servers() order by 2,3,4;
\! docker pause yb-tserver-0  
\! docker pause yb-tserver-9  






create table demo(id bigint primary key) split into 4 tablets;

\! sleep 60 ;  bin/yb-admin --init_master_addrs yb-master-0:7100 list_tablets ysql.yugabyte demo include_followers | awk '/^[0-9a-f]{8}/{gsub(/,/,"\n\tfollower: ",$NF);printf "Tablet %s [%6s - %6s]\n\tleader:   %s\t\n\tfollower: %s\n",$1,$3,$5,$(NF-2),$NF}' | grep --color=auto -P "^|leader|(?<=[.])[^.:]*"

alter table demo set tablespace "us-west";
\! sleep 60 ;  bin/yb-admin --init_master_addrs yb-master-0:7100 list_tablets ysql.yugabyte demo include_followers | awk '/^[0-9a-f]{8}/{gsub(/,/,"\n\tfollower: ",$NF);printf "Tablet %s [%6s - %6s]\n\tleader:   %s\t\n\tfollower: %s\n",$1,$3,$5,$(NF-2),$NF}' | grep --color=auto -P "^|leader|(?<=[.])[^.:]*"


alter table demo set tablespace "rf5";
\! sleep 60 ;  bin/yb-admin --init_master_addrs yb-master-0:7100 list_tablets ysql.yugabyte demo include_followers | awk '/^[0-9a-f]{8}/{gsub(/,/,"\n\tfollower: ",$NF);printf "Tablet %s [%6s - %6s]\n\tleader:   %s\t\n\tfollower: %s\n",$1,$3,$5,$(NF-2),$NF}' | grep --color=auto -P "^|leader|(?<=[.])[^.:]*"

alter table demo set tablespace "rf3";
\! sleep 60 ;  bin/yb-admin --init_master_addrs yb-master-0:7100 list_tablets ysql.yugabyte demo include_followers | awk '/^[0-9a-f]{8}/{gsub(/,/,"\n\tfollower: ",$NF);printf "Tablet %s [%6s - %6s]\n\tleader:   %s\t\n\tfollower: %s\n",$1,$3,$5,$(NF-2),$NF}' | grep --color=auto -P "^|leader|(?<=[.])[^.:]*"

alter table demo set tablespace "rf3-pref-eu";
\! sleep 60 ;  bin/yb-admin --init_master_addrs yb-master-0:7100 list_tablets ysql.yugabyte demo include_followers | awk '/^[0-9a-f]{8}/{gsub(/,/,"\n\tfollower: ",$NF);printf "Tablet %s [%6s - %6s]\n\tleader:   %s\t\n\tfollower: %s\n",$1,$3,$5,$(NF-2),$NF}' | grep --color=auto -P "^|leader|(?<=[.])[^.:]*"


select format('drop table if exists %I.%I cascade;',schemaname,tablename) from pg_tables where tableowner='yugabyte' and tablename like 'demo%';
\gexec

select format('drop tablespace if exists %I;',spcname) from pg_tablespace where spcoptions is not null;
\gexec
