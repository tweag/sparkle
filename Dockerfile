# Build environment for sparkle
FROM nixos/nix
MAINTAINER Mathieu Boespflug <m@tweag.io>

# stack --docker needs groupadd, which is found in the shadow package (only in edge).
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
RUN apk --update add ca-certificates python shadow

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable && nix-channel --update
ADD shell.nix /
RUN nix-shell /shell.nix
RUN nix-env -i stack
# This is necessary because Stack overrides the initial PATH to some hardcoded value.
RUN mkdir -p /usr/bin \
    && ln -s $(readlink -f $(which nix-shell)) /usr/bin/nix-shell

ADD entrypoint.py /
ENTRYPOINT ["/entrypoint.py"]
CMD ["/bin/bash"]
