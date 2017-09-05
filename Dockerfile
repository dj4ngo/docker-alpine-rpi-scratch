FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN /x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --initdb add busybox --allow-untrusted --purge --no-progress \
    mv /bin/busybox /bin/busybox.arm \
    file /bin/busybox.arm \
    ln -f /x86_64/busybox /bin/busybox \
    /x86_64/apk.static --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache add alpine-base ca-certificates --allow-untrusted --purge --no-progress \
    rm /bin/busybox \
    mv /bin/busybox.arm /bin/busybox 
   
