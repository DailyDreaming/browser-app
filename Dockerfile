# A Custom Docker Image for Running the UCSC Genome Browser.
#
# This downloads the UCSC Genome Browser setup bash script and installs it within the docker image.
# It will then be accessible via 127.0.0.1:8001 if that port is
# connected ("docker run -p 80:80" or "docker run -p 8001:8001").
#
# To build this image, run (in this directory):
#
#   docker build . -t {docker_username}/{tag_key}:{tag_value}
#
# For example:
#
#   docker build . -t dailydreaming/genome_browser:latest
#
# To push the image to a repository:
#
#   docker login
#   docker push {docker_username}/{tag_key}:{tag_value}
#
# For example:
#
#   docker login
#   docker push dailydreaming/genome_browser:latest
#
# Then, to run the Genome Browser (running locally on Ubuntu 18.04), something like:
#
#   docker run -p 8001:8001 dailydreaming/genome_browser:latest
#
# Go to 127.0.0.1:8001 in a web browser and you should see the Genome Browser.
#
# To drop into a shell in the currently running browser image, in a separate terminal, find
# the current docker ID using "docker ps" and then run:
#
#   docker exec -it {current_docker_id} bash
#
# For example:
#
#   docker exec -it 08d2785718a1 bash
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

# install old python versions
RUN add-apt-repository -y ppa:deadsnakes/ppa
RUN apt-get -y update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install python3.7-dev

# lock python3 to python3.7
RUN rm /usr/bin/python3 && ln -s /usr/bin/python3.7 /usr/bin/python3

# install our DRS resolver
RUN python3 -m pip install terra-notebook-utils
RUN which tnu
RUN tnu drs --help

# GBiC
ADD browserSetup.sh /tmp/browserSetup_raw.sh
# TODO: check if this is still a bug... but we patch one line in GBiC
RUN python3 -c 'f = open("/tmp/browserSetup_raw.sh"); new_content = f.read().replace("if $MYSQLADMIN -u root password $MYSQLROOTPWD;", "if /etc/init.d/mysql start && $MYSQLADMIN -u root password $MYSQLROOTPWD;"); f2 = open("/tmp/browserSetup.sh", "w"); f2.write(new_content); f.close(); f2.close()'
# TODO: seems to install fine but does not exit 0;  I think this may be the SQL socket being unavailable
# inside of the docker build but need to investigate.  It works for now.
RUN bash /tmp/browserSetup.sh -b install; exit 0
RUN cp $MYCNF /root/.mylogin.cnf
RUN apt-get install -y apache2 mariadb-server python-mysqldb libmariadbclient-dev gdb mysql-utilities
# RUN bash -x /tmp/browserSetup.sh -b minimal hg38 hg19

# we need these directories or cram doesn't work
RUN mkdir -p /userdata/cramCache/error
# TODO: Too permissive
RUN chmod 777 /userdata/cramCache/error
RUN mkdir -p /userdata/cramCache/pending
# TODO: Too permissive
RUN chmod 777 /userdata/cramCache/pending

# wget https://www.ebi.ac.uk/ena/cram/md5/2b3a55ff7f58eb308420c8a9b11cac50
# wget https://www.ebi.ac.uk/ena/cram/md5/f98db672eb0993dcfdabafe2a882905c
# TODO: which others do we need?
ADD 2b3a55ff7f58eb308420c8a9b11cac50 /userdata/cramCache/2b3a55ff7f58eb308420c8a9b11cac50
ADD f98db672eb0993dcfdabafe2a882905c /userdata/cramCache/f98db672eb0993dcfdabafe2a882905c

# RUN git clone git://genome-source.soe.ucsc.edu/kent.git && cd kent && git checkout -t -b beta origin/beta && cd src && make -j4 cgi-alpha
RUN cd $APACHEDIR && git clone https://github.com/diekhans/kent.git && cd kent && git checkout udc-protocols
# this makefile is missing an "install" target, so we patch it
COPY hubcheck.makefile $APACHEDIR/kent/src/hg/utils/hubCheck/makefile

# compile the browser code from source
ADD srcCompile.sh /tmp/srcCompile.sh
RUN bash /tmp/srcCompile.sh

# drs resolving script for resolvCmd
COPY drs.sh /usr/local/bin/drs.sh
RUN chmod 755 /usr/local/bin/drs.sh
RUN chmod +x /usr/local/bin/drs.sh

# RUN echo '{"workspace": "$(WORKSPACE_NAME)", "workspace_namespace": "$(WORKSPACE_NAMESPACE)", "copy_progress_indicator_type": "auto"}' > /var/www/.tnu_config

# modify hg.conf
RUN echo "cramRef=/userdata/cramCache" >> $APACHEDIR/cgi-bin/hg.conf
RUN echo "resolvProts=drs" >> $APACHEDIR/cgi-bin/hg.conf
RUN echo "resolvCmd=/usr/local/bin/drs.sh" >> $APACHEDIR/cgi-bin/hg.conf

# may be able to remove this?
RUN mkdir -p /usr/local/apache/trash
# TODO: Too permissive
RUN chmod 777 /usr/local/apache/trash

# s6-overlay is a daemon manager; good practice for running one docker with more than one process
RUN curl -SLO "https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-${ARCH}.tar.gz" \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C / \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C /usr ./bin \
  && rm -rf s6-overlay-${ARCH}.tar.gz

# s6-overlay will run these two scripts (Apache and SQL) when the container starts
COPY 00-mysql.sh /etc/cont-init.d/00-mysql.sh
COPY 10-browser.sh /etc/cont-init.d/10-browser.sh

# s6-overlay main program (only runs sleep infinite)
RUN mkdir /etc/services.d/genomebrowserapache
COPY genomebrowserapache/run /etc/services.d/genomebrowserapache/run
RUN chmod 755 /etc/services.d/genomebrowserapache/run
RUN chmod +x /etc/services.d/genomebrowserapache/run

# tell apache to use port 8001
COPY ports.conf /etc/apache2/

# index.html with "terms to accept" widget pasted at end (accept.html.txt)
# TODO: edit this into index.html just before "<\body><\html>"
# COPY index.html /usr/local/apache/htdocs/index.html

# test script for checking and running credentials in a live browser session
COPY testcreds /usr/local/apache/cgi-bin/testcreds
RUN chmod 755 /usr/local/apache/cgi-bin/testcreds
RUN chmod +x /usr/local/apache/cgi-bin/testcreds

# needed for PassEnv to pass environment variables set originally for root to the www-data user
COPY 001-browser.conf /etc/apache2/sites-available/001-browser.conf
COPY 001-browser.conf /etc/apache2/sites-enabled/001-browser.conf

# already activated, but needed to pass env vars to the www-data user
# RUN a2enmod headers
# RUN a2enmod env

# install gcloud
RUN apt-get update
RUN apt-get install apt-transport-https ca-certificates gnupg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update
RUN apt-get install google-cloud-cli

# env vars that are input when the docker is launched now, not when the docker image is built
ENV WORKSPACE_NAME=terra-notebook-utils-tests
ENV WORKSPACE_NAMESPACE=firecloud-cgl
ENV GOOGLE_PROJECT=firecloud-cgl

# TODO: Most of these ports are not needed.  Probably only 80 (HTTP), 443 (HTTPS), 3306 (SQL), and 8001?
EXPOSE 3306 33060 8000 8001 80 443 3333 873

# old entrypoint before using s6-overlay
# ENTRYPOINT ["sh", "-c", "export GOOGLE_PROJECT=anvil-stage-demo; export WORKSPACE_NAME=scratch-lon; /etc/init.d/mysql start; apachectl -D FOREGROUND"]

# s6-overlay's entrypoint
ENTRYPOINT ["/init"]
