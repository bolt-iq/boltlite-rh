FROM registry.access.redhat.com/rhel7

MAINTAINER SWAT Solutions <rburton@swatsolutions.com>



### Atomic/OpenShift Labels - https://github.com/bolt-iq/boltlite-rh

LABEL name="swatsolutions/boltlite" \
      maintainer="Richard-rburton@swatsolutions.com" \
      vendor="SWAT Solutions" \
      version="1.0" \
      release="1" \
      summary="SWAT Solutions Bolt Lite Container" \
      description="BOLT Lite is the free version of BOLT Test, providing a way for teams to get started in Automation." \

### Required labels above - recommended below

      url="https://www.boltiq.io" \
      run='docker run -tdi --name ${NAME} ${IMAGE} -p 5901:5901' \
      io.k8s.description="BOLT Lite is the free version of BOLT Test, providing a way for teams to get started in Automation." \
      io.k8s.display-name="Bolt Lite" \
      io.openshift.expose-services="" \
      io.openshift.tags="SWAT Solutions,Bolt Lite"



### Atomic Help File - Write in Markdown, it will be converted to man format at build time.

### https://github.com/bolt-iq/boltlite-rh/readme.md

COPY README.md /tmp/

### add licenses to this directory

COPY licenses /licenses

### Add necessary Red Hat repos here

RUN REPOLIST=rhel-7-server-rpms,rhel-7-server-optional-rpms \

### Add your package needs here

    INSTALL_PKGS="golang-github-cpuguy83-go-md2man" && \

    yum -y update-minimal --disablerepo "*" --enablerepo rhel-7-server-rpms --setopt=tsflags=nodocs \

      --security --sec-severity=Important --sec-severity=Critical && \

    yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs ${INSTALL_PKGS} && \

### help file markdown to man conversion

    go-md2man -in /tmp/README.md -out /README.1 && \

    yum clean all

### Setup user for build execution and application runtime

ENV APP_ROOT=/home/bolt \
    USER_NAME=bolt \
    USER_UID=10001

ENV APP_HOME=${APP_ROOT}/src  PATH=$PATH:${APP_ROOT}/bin

RUN mkdir -p ${APP_HOME}

COPY . ${APP_ROOT}/bin/

RUN chmod -R u+x ${APP_ROOT}/bin && \
   useradd -l -u ${USER_UID} -r -g 0 -d ${APP_ROOT} -s /sbin/nologin -c "${USER_NAME} user" ${USER_NAME} && \
   chown -R ${USER_UID}:0 ${APP_ROOT} && \
   chmod -R g=u ${APP_ROOT}

####### Add BOLT Lite Requirements below. #######
# Install VNC and KDE
RUN yum -y  install tigervnc-server
RUN yum -y  install tigervnc
RUN yum -y groupinstall "X Window System" "KDE" 

# Install Java
#ADD jdk-8u161-linux-x64.rpm /home
RUN yum -y install ${APP_ROOT}/bin/jdk-8u161-linux-x64.rpm

# Replacement for systemctl running in container
COPY ./systemctl.py /usr/bin/

# add VNC Users before running setup default user takes care of this step
#CMD useradd bolt
#CMD passwd bolt
#CMD echo "password"
#CMD echo "password"

# Run this as entry point to clean and run each time
#ADD vncconfig3.sh /usr/bin/vncconfig3.sh
#CMD chmod +x /usr/bin/vncconfig3.sh
#CMD chmod -R 777 /usr/bin/vncconfig3.sh
# Configure VNC
RUN ${APP_ROOT}/bin/vncconfig3.sh

# copy files to container
COPY code/ /src/
RUN chmod -R 777 /src/
WORKDIR /

RUN yum -y install wget
RUN yum -y install unzip
RUN yum -y install curl

# Install Intellij
WORKDIR /tmp
RUN wget -q 'https://download.jetbrains.com/idea/ideaIC-2017.3.4.tar.gz' && \
    tar xzf ideaIC-2017.3.4.tar.gz && rm ideaIC-2017.3.4.tar.gz && \
    mv idea-* /opt/idea && \
    ln -s /opt/idea/bin/idea.sh /usr/local/bin/idea.sh

# Add launcher
COPY intellij.desktop /usr/share/applications/intellij.desktop

# Install chrome
COPY google-chrome.repo /etc/yum.repos.d/google-chrome.repo
RUN yum -y  install google-chrome-stable
COPY google-chrome /opt/google/chrome/
RUN chmod -R 777 /opt/google/chrome/

# Install Gauge
RUN curl -SsL https://downloads.gauge.org/stable | sh
RUN gauge install java
RUN gauge install html-report
RUN gauge install xml-report
RUN gauge install json-report 
RUN gauge install flash
RUN gauge install spectacle

### Containers should NOT run as root as a good practice

USER 10001

WORKDIR ${APP_ROOT}

VOLUME ${APP_ROOT}/logs ${APP_ROOT}/data

ENTRYPOINT rm -f /tmp/.X1-lock && rm -f /tmp/.X11-unix/X1 && vncserver -SecurityTypes None && /bin/bash
