/*
psql -p 5433 -d yugabyte -U yugabyte -ef client/yftt-tablespaces.sql

*/
select format('drop table if exists %I.%I cascade;',schemaname,tablename) from pg_tables where tableowner='yugabyte' and tablename like 'demo%';
\gexec

select format('drop tablespace if exists %I;',spcname) from pg_tablespace where spcoptions is not null;
\gexec

create tablespace "eu-west" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "eu-west", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "eu-west", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

create tablespace "us-east" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

create tablespace "us-west" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az2"   , "min_num_replicas": 1 },
{ "cloud": "cloud", "region": "us-west", "zone": "az3"   , "min_num_replicas": 1 }
    ]
} $$) ;

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

create tablespace "rf3-pref-eu" with ( replica_placement= $$
{
    "num_replicas": 3,
    "placement_blocks": [
{ "cloud": "cloud", "region": "eu-west", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 1 },
{ "cloud": "cloud", "region": "us-east", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 2 },
{ "cloud": "cloud", "region": "us-west", "zone": "az1"   , "min_num_replicas": 1 
  , "leader_preference": 3 }
    ]
} $$) ;

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


