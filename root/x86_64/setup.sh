#!/x86_64/busybox sh


#(while [ ! -f  "/bin/busybox" ]; do
#	sleep 0.1
#done &&\
#echo DETECTED &&\
#mv /bin/busybox /bin/busybox.arm &&\
#ln -f /x86_64/busybox /bin/busybox )&
#PID="$$"

set -x
/x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add busybox --allow-untrusted --purge --no-progress

mv /bin/busybox /bin/busybox.arm &&\
ln -f /x86_64/busybox /bin/busybox )&

/x86_64/apk.static -v --arch armhf --repository http://nl.alpinelinux.org/alpine/latest-stable/main  --update-cache --root / --initdb add alpine-base ca-certificates --allow-untrusted --purge --no-progress

#kill $PID

rm /bin/busybox
mv /bin/busybox.arm /bin/busybox
