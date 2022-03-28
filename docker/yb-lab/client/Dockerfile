FROM public.ecr.aws/lambda/java:latest
RUN mkdir client
WORKDIR client
RUN yum install -y git curl wget vim postgresql
ADD hikari.properties ybdemo.sh YBDemo.jar metrics_snap.sh ybwr.sql .
ENV YBDEMO_DOMAIN ""
ENV YBDEMO_CASE "connect"
ENV YBDEMO_THREADS "5"
ENTRYPOINT [ -n "${YBDEMO_DOMAIN}" ] && sed -e 's?yb-tserver-[0-9]*?&.'"${YBDEMO_DOMAIN}"'?' -i hikari.properties ; \
 bash ybdemo.sh "${YBDEMO_CASE}" "${YBDEMO_THREADS}" 

