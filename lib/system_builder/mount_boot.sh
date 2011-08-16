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
    # list partitions first
    (ls /dev/hd*[1-9] /dev/sd*[1-9] /dev/sr[0-9]; ls /dev/hd[a-z] /dev/sd[a-z]) 2> /dev/null
}

mkdir /boot

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

echo "no image found"
exit 1
