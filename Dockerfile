FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN set -x \
    sh -c "set -x; until [ -f  "/bin/busybox" ]; do sleep 1 ;done ; echo DETECTED; mv /bin/busybox /bin/busybox.arm ; ln /x86_64/busybox /bin/busybox" & \
    /x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress
    

