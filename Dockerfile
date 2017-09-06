FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN /x86_64/apk.static -v --arch armhf --root / --force --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --initdb add busybox --allow-untrusted --purge --no-progress --no-scripts &&\
    cross-build-start &&\
    /x86_64/apk.static --arch armhf --root / --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache add alpine-base ca-certificates --allow-untrusted --purge --no-progress &&\
    cross-build-end
   
