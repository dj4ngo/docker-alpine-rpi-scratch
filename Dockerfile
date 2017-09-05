FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN install.sh

