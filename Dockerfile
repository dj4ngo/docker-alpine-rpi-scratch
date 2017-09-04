FROM scratch
LABEL maintainer="sebastien@boyron.eu"
COPY root /
RUN /x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress
RUN ls -l /bin

