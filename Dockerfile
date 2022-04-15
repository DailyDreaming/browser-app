# A Custom Docker Image for Running the UCSC Genome Browser.
#
# This downloads the UCSC Genome Browser setup bash script and installs it within the docker image.
# It will then be accessible via 127.0.0.1:80 or 127.0.0.1:8000 if those ports are
# connected ("docker run -p 80:80" or "docker run -p 8000:8000").
#
# To build this image, run:
#
#   docker login
#   docker build . -t {docker_username}/{tag_key}:{tag_value}
#   docker push {docker_username}/{tag_key}:{tag_value}
#
# For example:
#
#   docker login
#   docker build . -t dailydreaming/genome_browser:latest
#   docker push dailydreaming/genome_browser:latest
#
# Then, to run the Genome Browser (running locally on Ubuntu 18.04):
#
# docker run -p 8001:8001 --entrypoint /bin/bash dailydreaming/genome_browser:latest -c '/etc/init.d/mysql start && apachectl -D FOREGROUND'
#
# Go to 127.0.0.1:8000 in a web browser and you should see the Genome Browser.
#
# Notes:
#
#  - To make this compatible with Terra we build on their suggested base image, "terra-jupyter-base":
#        https://github.com/DataBiosphere/terra-docker/blob/master/terra-jupyter-base/Dockerfile
#
#  - Terra only currently has support for: docker.io or gcr.io, so upload there (docker.io is free)
#
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV APACHEDIR=/usr/local/apache
ENV MACHTYPE=x86_64
ENV USER=root
ENV USER_NAME=root
ENV RSTUDIO_HOME=unused
ENV VNC_PW=terra
ENV ARCH=x86
ENV MYCNF=/etc/mysql/my.cnf

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y libfreetype6-dev software-properties-common libssl-dev python3-pip python3-dev python-dev git zip unzip wget build-essential apt-transport-https curl cmake rsync libpcap-dev libpng-dev ghostscript gmt r-base uuid-dev

RUN add-apt-repository -y ppa:deadsnakes/ppa
RUN apt-get -y update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install python3.7-dev

RUN rm /usr/bin/python3 && ln -s /usr/bin/python3.7 /usr/bin/python3

ADD browserSetup.sh /tmp/browserSetup_raw.sh
RUN python3 -c 'f = open("/tmp/browserSetup_raw.sh"); new_content = f.read().replace("if $MYSQLADMIN -u root password $MYSQLROOTPWD;", "if /etc/init.d/mysql start && $MYSQLADMIN -u root password $MYSQLROOTPWD;"); f2 = open("/tmp/browserSetup.sh", "w"); f2.write(new_content); f.close(); f2.close()'
RUN bash /tmp/browserSetup.sh -b install; exit 0
RUN cp $MYCNF /root/.mylogin.cnf
RUN apt-get install -y apache2 mariadb-server python-mysqldb libmariadbclient-dev gdb mysql-utilities

RUN mkdir -p /userdata/cramCache/error
RUN chmod 777 /userdata/cramCache/error
RUN mkdir -p /userdata/cramCache/pending
RUN chmod 777 /userdata/cramCache/pending
ADD 2b3a55ff7f58eb308420c8a9b11cac50 /userdata/cramCache/2b3a55ff7f58eb308420c8a9b11cac50

RUN cd $APACHEDIR && wget http://hgdownload.soe.ucsc.edu/admin/jksrc.zip && unzip jksrc.zip && rm -f jksrc.zip

RUN echo "cramRef=/userdata/cramCache" >> $APACHEDIR/cgi-bin/hg.conf

RUN mkdir -p /usr/local/apache/trash
RUN chmod 777 /usr/local/apache/trash

RUN curl -SLO "https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-${ARCH}.tar.gz" \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C / \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C /usr ./bin \
  && rm -rf s6-overlay-${ARCH}.tar.gz

COPY 00-mysql.sh /etc/cont-init.d/00-mysql.sh
COPY 10-browser.sh /etc/cont-init.d/10-browser.sh

RUN mkdir /etc/services.d/genomebrowserapache
COPY genomebrowserapache/run /etc/services.d/genomebrowserapache/run
RUN chmod 777 /etc/services.d/genomebrowserapache/run

COPY ports.conf /etc/apache2/

COPY index.html /usr/local/apache/htdocs/index.html

EXPOSE 3306 8001 80 443

ENTRYPOINT ["/init"]

