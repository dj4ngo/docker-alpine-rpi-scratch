#!/bin/sh

set -x 

mv /bin/sh /bin/sh.orig >&2
cat << 'EOF' >/bin/sh
#!/bin/sh

set -x
case "$(uname -m)" in )
	"x86_64")
		qemu-arm-static ${@}
		;;
	"arm")
		${@}
		;;
esac
EOF
chmod +x /bin/sh

qemu-arm-static apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress >&2

