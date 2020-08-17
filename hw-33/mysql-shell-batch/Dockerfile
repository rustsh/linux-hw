FROM oraclelinux:7-slim

ARG KEY=https://repo.mysql.com/RPM-GPG-KEY-mysql
ARG REPO=https://repo.mysql.com

ARG MYSQL_SHELL_PACKAGE_URL=$REPO/yum/mysql-tools-community/el/7/x86_64/mysql-shell-1.0.11-1.el7.x86_64.rpm

RUN rpmkeys --import $KEY \
  && yum install -y $MYSQL_SHELL_PACKAGE_URL \
  && yum clean all
COPY run.sh /run.sh
RUN chmod +x /run.sh

## Add the wait script to the image
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.7.3/wait /wait
RUN chmod +x /wait

## Launch the wait tool and then your application
CMD /wait && /run.sh mysqlsh
