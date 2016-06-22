# Build environment for sparkle
FROM ubuntu:xenial
MAINTAINER Arnaud Bailly <arnaud@igitur.io>

# install GHC
# from https://github.com/freebroccolo/docker-haskell/blob/master/7.10/Dockerfile
ENV LANG            C.UTF-8

RUN echo 'deb http://download.fpcomplete.com/ubuntu xenial main' > /etc/apt/sources.list.d/fpco.list && \
    echo 'deb http://ppa.launchpad.net/cwchien/gradle/ubuntu xenial main' > /etc/apt/sources.list.d/gradle.list && \
    # fpco key
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C5705533DA4F78D8664B5DC0575159689BEFB442 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3D16156328D0E3056D885D0BD7CC6F019D06AF36 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      gradle \
      netbase \
      # we need JDK because jre does not ship with libjvm.so...
      openjdk-8-jdk \
      stack
