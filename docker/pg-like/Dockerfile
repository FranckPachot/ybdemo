FROM yugabytedb/yugabyte:latest
ENV YB_MASTER ""
ENV YB_RF     "1"
WORKDIR /home/yugabyte
ADD  yb-cmd.sh .
ADD  yb-healthcheck.sh .
ADD  yb-create-if-not-exists.sh .
VOLUME /data
HEALTHCHECK --interval=1s --timeout=1s --start-period=15s --retries=3 CMD [ -f yb-create.done ] && sh yb-healthcheck.sh
CMD sh yb-cmd.sh /data 7100 $YB_MASTER
