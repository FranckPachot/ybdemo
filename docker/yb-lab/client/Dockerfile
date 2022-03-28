FROM public.ecr.aws/lambda/java:latest
RUN  yum update -y && yum install -y git curl wget vim postgresql && yum clean all
RUN  mkdir client
WORKDIR client
ADD  hikari.properties ybdemo.sh YBDemo.jar metrics_snap.sh ybwr.sql .
RUN  sed -e 's/ysqlsh/psql/g' -i ybdemo.sh
ENV  YBDEMO_DOMAIN ""
ENV  YBDEMO_CASE "connect"
ENV  YBDEMO_THREADS "5"
ENTRYPOINT [ -n "${YBDEMO_DOMAIN}" ] && sed -e 's?yb-tserver-[0-9]*?&.'"${YBDEMO_DOMAIN}"'?' -i ybdemo.sh hikari.properties ; \
 bash ybdemo.sh "${YBDEMO_CASE}" "${YBDEMO_THREADS}" 

