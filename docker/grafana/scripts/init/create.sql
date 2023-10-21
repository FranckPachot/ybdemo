drop table if exists demo;
create table if not exists demo
(id bigint, primary key(id asc), num bigint, value text);
insert into demo ( id, num )
 select id , 0 from generate_series(1,1000000) id;
