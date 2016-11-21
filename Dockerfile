# Build environment for sparkle
FROM nixos/nix
MAINTAINER Mathieu Boespflug <m@tweag.io>

# stack --docker needs groupadd, which is found in the shadow package (only in edge).
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
RUN apk --update add ca-certificates python shadow

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable && nix-channel --update
ADD shell.nix /
RUN nix-shell /shell.nix
# This is necessary because Stack overrides the initial PATH to some hardcoded value.
RUN mkdir -p /usr/bin \
    && ln -s $(readlink -f $(which nix-shell)) /usr/bin/nix-shell

# Workaround for Java getLocalHost() failure.
# https://github.com/1science/docker-elasticsearch/issues/1#issuecomment-106307522
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# A very long line in /etc/group is not necessary and prevents newer groups to
# be found. Fixes the error:
#   $ stack --docker --docker-image sparkle build
#   Running /usr/sbin/useradd -oN --uid 1000 --gid 1000 --home .../_home stack exited with ExitFailure 6
#   useradd: group '1000' does not exist
RUN sed -i 's/nixbld:x:30000:.*/nixbld:x:30000:/g' /etc/group

ADD entrypoint.py /
ENTRYPOINT ["/entrypoint.py"]
CMD ["/bin/bash"]
