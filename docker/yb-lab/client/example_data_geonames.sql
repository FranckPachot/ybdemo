/*
 https://medium.com/pixel-heart/howto-dump-geonames-into-postgresql-and-postgis-395fab58f4bc
*/

\! wget -qc http://download.geonames.org/export/dump/allCountries.zip
\! wget -qc http://download.geonames.org/export/dump/alternateNames.zip
\! wget -qc http://download.geonames.org/export/dump/countryInfo.txt
\! [ -f allCountries.txt ] || unzip allCountries.zip
\! [ -f alternateNames.txt ] || unzip alternateNames.zip

drop table if exists geoname, alternatename, countryinfo;

create table geoname (
    geonameid   int primary key,
    name text,
    asciiname text,
    alternatenames text,
    latitude float,
    longitude float,
    fclass char(1),
    fcode text,
    country text,
    cc2 text,
    admin1 text,
    admin2 text,
    admin3 text,
    admin4 text,
    population bigint,
    elevation int,
    gtopo30 int,
    timezone text,
    moddate date
 );
create table alternatename (
    alternatenameId int primary key,
    geonameid int,
    isoLanguage text,
    alternateName text,
    isPreferredName boolean,
    isShortName boolean,
    isColloquial boolean,
    isHistoric boolean
 );
create table "countryinfo" (
    iso_alpha2 text primary key,
    iso_alpha3 text,
    iso_numeric integer,
    fips_code text,
    name text,
    capital text,
    areainsqkm double precision,
    population integer,
    continent text,
    tld text,
    currencycode text,
    currencyname text,
    phone text,
    postalcode text,
    postalcoderegex text,
    languages text,
    geonameId int,
    neighbors text,
    equivfipscode text
);

set yb_disable_transactional_writes=on;


\copy geoname (geonameid,name,asciiname,alternatenames,latitude,longitude,fclass,fcode,country,cc2,admin1,admin2,admin3,admin4,population,elevation,gtopo30,timezone,moddate) from 'allCountries.txt' null as '';
\copy alternatename  (alternatenameid,geonameid,isolanguage,alternatename,ispreferredname,isshortname,iscolloquial,ishistoric) from 'alternateNames.txt' null as '';
\copy countryinfo (iso_alpha2,iso_alpha3,iso_numeric,fips_code,name,capital,areainsqkm,population,continent,tld,currencycode,currencyname,phone,postalcode,postalcoderegex,languages,geonameid,neighbors,equivfipscode) from 'countryInfo.txt' null as '';

set yb_disable_transactional_writes=on;

ALTER TABLE ONLY countryinfo
      ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
ALTER TABLE ONLY alternatename
      ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
