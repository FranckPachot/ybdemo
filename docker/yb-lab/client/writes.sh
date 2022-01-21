java -jar YBDemo.jar << 'SQL'
create table if not exists demo(id bigint generated always as identity, ts timestamptz default clock_timestamp(), message text, primary key(id hash));
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
insert into demo(message) values (format('inserted when connected to %s',current_setting('listen_addresses'))) returning row_to_json(demo);
select format('Rows inserted in the last minute: %s',to_char(count(*),'999999999')) from demo where ts > clock_timestamp() - interval '1 minute';
SQL
exit
