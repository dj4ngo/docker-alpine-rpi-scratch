FROM scratch
LABEL maintainer="sebastien@boyron.eu"
COPY root /
#ADD http://nl.alpinelinux.org/alpine/latest-stable/main/armhf/apk-tools-static-2.7.2-r0.apk /usr/bin
RUN /x86_64/busybox ls -Rl /
RUN /usr/bin/qemu-arm-static /sbin/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress
RUN ls -l /bin

