FROM scratch
ADD https://github.com/dj4ngo/docker-rpi-alpine-scratch/releases/download/v0.1.14/rootfs.tgz /
CMD ["sh"]

