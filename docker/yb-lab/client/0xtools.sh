type apt-get && apt-get install -y git make gcc python procps
type yum     && yum install -y git make gcc python procps
cd
git clone https://github.com/tanelpoder/0xtools
make
make install
psn -a
schedlat $(pgrep pgbench)

