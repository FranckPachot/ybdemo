#FROM public.ecr.aws/lambda/java:latest
FROM yugabytedb/yugabyte
RUN mkdir client
WORKDIR client
RUN yum install -y git curl wget vim postgresql
ADD hikari.properties ybdemo.sh YBDemo.jar metrics_snap.sh ybwr.sql .
ENV YBDEMO_DOMAIN ""
ENV YBDEMO_CASE "connect"
ENV YBDEMO_THREADS "5"
# use psql instead of ysqlsh, to show compatibility
RUN sed -e 's/ysqlsh/psql/g' ybdemo.sh
# add domain name if defined
ENTRYPOINT [ -n "${YBDEMO_DOMAIN}" ] && sed -e 's?yb-tserver-[0-9]*?&.'"${YBDEMO_DOMAIN}"'?' -i hikari.properties ybdemo.sh ; \
 bash ybdemo.sh "${YBDEMO_CASE}" "${YBDEMO_THREADS}" 
