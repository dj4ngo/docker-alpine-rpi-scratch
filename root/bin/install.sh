#!/bin/sh

set -x 

mv /bin/sh /bin/sh.orig
cat << EOF >/bin/sh
#!/bin/sh

set -x
qemu-arm-static ${@}
EOF

qemu-arm-static apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress

mv /bin/sh.orig /bin/sh
