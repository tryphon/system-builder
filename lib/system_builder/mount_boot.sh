#!/bin/sh -x

get_fstype() {
	# udev >=146-1 no longer provides vol_id:
	if [ -x /lib/udev/vol_id ]
	then
		/lib/udev/vol_id -t ${1} 2>/dev/null
	else
		eval $(blkid -o udev "${1}")
		if [ -n "$ID_FS_TYPE" ]
		then
			echo "${ID_FS_TYPE}"
		fi
	fi
}

list_devices() {
    # try boot label, list partitions first and then disks
    (ls /dev/disk/by-label/boot; ls /dev/hd*[1-9] /dev/sd*[1-9] /dev/vd*[1-9] /dev/sr[0-9]; ls /dev/hd[a-z] /dev/sd[a-z] /dev/vd[a-z]) 2> /dev/null
}

mkdir /boot

if [ -n "${nfsroot}" ]; then
  . /scripts/functions
	configure_networking

	if [ -z "${nfsopts}" ]; then
		nfsopts="retrans=10"
	fi

  echo "check if ${nfsroot} provided boot image"
  nfsmount -o nolock,ro,${nfsopts} ${nfsroot} /boot
  if [ -f "/boot/filesystem.squashfs" ]; then
      exit 0
  else
      echo "no image found on nfs"
      exit 1
  fi
else
    for device in `list_devices`; do
        fs_type=`get_fstype ${device}`
        echo "check if $device ($fs_type) is the boot image"

        case $fs_type in
            ext2|ext3|iso9660)
                mount -r -t $fs_type $device /boot
                if [ -f "/boot/config.pp" ]; then
                    exit 0
                else
                    umount /boot
                fi
                ;;
        esac
    done
fi

echo "no image found"
exit 1
