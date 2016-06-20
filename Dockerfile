# Build environment for sparkle
FROM ubuntu:xenial
MAINTAINER Arnaud Bailly <arnaud@igitur.io>

# install GHC
# from https://github.com/freebroccolo/docker-haskell/blob/master/7.10/Dockerfile
ENV LANG            C.UTF-8

RUN echo 'deb http://ppa.launchpad.net/hvr/ghc/ubuntu xenial main' > /etc/apt/sources.list.d/ghc.list && \
    echo 'deb http://download.fpcomplete.com/ubuntu xenial main'   > /etc/apt/sources.list.d/fpco.list  && \
    # hvr keys
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F6F88286 && \
    # fpco keys
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C5705533DA4F78D8664B5DC0575159689BEFB442 && \
    apt-get update && \
    apt-get install -y --no-install-recommends netbase wget unzip cabal-install-1.22 ghc-7.10.3 happy-1.19.5 alex-3.1.4 \
            stack zlib1g-dev libtinfo-dev libsqlite3-0 libsqlite3-dev ca-certificates g++

# install JDK
# we need JDK because jre does not ship with libjvm.so...
RUN apt-get install -y openjdk-8-jdk  && \
    rm -rf /var/lib/apt/lists/*

# install Gradle
RUN wget -O /tmp/gradle-2.14-bin.zip https://services.gradle.org/distributions/gradle-2.14-bin.zip && \
    unzip -d /opt /tmp/gradle-2.14-bin.zip

ENV PATH /root/.cabal/bin:/root/.local/bin:/opt/cabal/1.22/bin:/opt/gradle-2.14/bin:/opt/ghc/7.10.3/bin:/opt/happy/1.19.5/bin:/opt/alex/3.1.4/bin:$PATH
ENV GRADLE_HOME /opt/gradle-2.14

