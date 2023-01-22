POSTGRES_USER="${POSTGRES_USER:-yugabyte}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-yugabyte}"
POSTGRES_DB="${POSTGRES_DB:-$POSTGRES_USER}"
PGPASSWORD=yugabyte ysqlsh -e -h "$(hostname)" -c "
alter user postgres password '${POSTGRES_PASSWORD}'
" -c "
alter user yugabyte password '${POSTGRES_PASSWORD}';
" -c "
create user ${POSTGRES_USER} password '${POSTGRES_PASSWORD}'
" -c "
create database ${POSTGRES_DB}
" 
echo '\c' | PGPASSWORD=${POSTGRES_PASSWORD} ysqlsh -h "$(hostname)" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 && date > yb-create.done
