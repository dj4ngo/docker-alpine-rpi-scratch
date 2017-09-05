FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN sh -c " while [ "$(readlink /bin/sh)" == "/x86_64/busybox" ]; do sleep 1 ;done ; ln -sf /x86_64/busybox /bin/sh" & \
    PID=$$ \
    /x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress \
    kill $PID
    

