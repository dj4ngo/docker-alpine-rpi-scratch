FROM scratch

LABEL maintainer="sebastien@boyron.eu"

COPY root /

RUN /x86_64/setup.sh
