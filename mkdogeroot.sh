#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
	echo "please run this program with UID 0"
	exit 1
fi

bindest="/tmp"
chrootdest="/mnt"

while getopts 'u:b:c:f' c
do
	case $c in
	u)
		user=$OPTARG
		;;
	b)
		bindest=$OPTARG
		;;
	c)
		chrootdest=$OPTARG
		;;
	f)
		makefun=1
		;;
	*)
		echo "unknown flag $c"
		exit 1
		;;
	esac
done

shift $((OPTIND - 1))

moredir=$*

usage() {
	printf "%s -u <target user> [-b <sudo script directory>] " "$0"
	echo "[-c <chroot directory>] [more directories to mount...]"
	exit 1
}

[ $# -lt 1 ] && usage

if ! id "${user}">/dev/null 2>&1; then
	echo "unknown user ${user}"
	exit 1
fi

for d in ${bindest} ${chrootdest}
do
	if [ ! -d "${d}" ]; then
		echo "${d} non existant directory"
		exit 1
	fi
done

echo "target: ${user}"
echo "sudo scripts directory: ${bindest}"
echo "chroot directory: ${chrootdest}"
echo "additional directories: ${moredir}"
[ -n "$makefun" ] && echo "makefun is set"
printf "is this correct? [y/N] "
read -r r

[ "$r" != "y" ] && exit 0

chrootsh=${bindest}/mkchroot
unsharesh=${bindest}/broot
rmrootsh=${bindest}/rmroot

kdirs="proc dev sys run"
udirs="bin boot sbin lib lib64 media opt sbin srv usr var"

cat >"${chrootsh}"<<EOF
#!/bin/sh

cd $chrootdest

mkdir -p $kdirs $udirs tmp $moredir root mnt etc home

mount --make-rshared /

mount --make-rslave /dev
mount --make-rslave /run

mount -t proc /proc proc
mount -t sysfs /sys sys
mount --rbind /dev dev
mount --rbind /run run

for d in $udirs
do
        mount --bind -o ro /\$d \$d
done
for d in $moredir tmp
do
	mount --bind /\$d \$d
done

if [ -n "$makefun" ]; then
	echo "   wow root"
	echo "         such uid"
	echo
	echo "many privileges"
	echo
fi

# enter chroot
exec chroot . /bin/sh

EOF

cat >"${unsharesh}"<<EOF
#!/bin/sh

sudo unshare -m ${chrootsh}
EOF

cat >"${rmrootsh}"<<EOF
#!/bin/sh

cd /

echo "umounting remaining mounts"
umount --recursive ${chrootdest}/* || true

cd $chrootdest

echo "removing mount points"
if [ "\$(find . -type f|wc -l)" = 0 ]; then
	rm -rf $kdirs $udirs tmp $moredir
fi

echo "removing scripts"
rm -f ${chrootsh} ${unsharesh} ${rmrootsh}
echo "removing ${user} sudo access"
sed -i "\\,${user}.*${chrootsh},d" /etc/sudoers

echo "fakeroot mode deleted for user ${user}"
EOF

chmod 711 "${chrootsh}" "${unsharesh}" "${rmrootsh}"

echo "${user}  ALL=(ALL) NOPASSWD: ${chrootsh}, ${unsharesh}" >>/etc/sudoers

