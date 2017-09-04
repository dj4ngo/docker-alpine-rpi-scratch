FROM scratch
LABEL maintainer="sebastien@boyron.eu"
ADD https://github.com/dj4ngo/docker-rpi-alpine-scratch/releases/download/v0.1.25/rootfs.tgz /
CMD sh

