FROM scratch
LABEL maintainer="sebastien@boyron.eu"
ADD https://github.com/dj4ngo/docker-rpi-alpine-scratch/releases/download/v0.1.23/rootfs.tgz /
CMD ["/bin/sh"]

