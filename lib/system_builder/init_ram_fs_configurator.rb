class SystemBuilder::InitRamFsConfigurator 

  def configure(chroot)
    puts "* install initramfs-tools"
    chroot.apt_install %w{initramfs-tools syslinux}

    install_script(chroot, "local-top/mount_boot") do |f|
      f.puts "modprobe loop"
      f.puts "/lib/initrd/mount_boot"
      # f.puts "PS1='(initramfs) ' /bin/sh -i </dev/console >/dev/console 2>&1"
    end

    install_script(chroot, "local-bottom/move_boot") do |f|
      f.puts "mount -n -o move /boot /root/boot"
    end

    install_hook(chroot, "mount_boot") do |f|
      f.puts "mkdir -p $DESTDIR/lib/initrd/"
      f.puts "install -m 755 /usr/local/share/initramfs-tools/mount_boot $DESTDIR/lib/initrd/"
    end

    chroot.image.open("/etc/initramfs-tools/modules") do |f|
      f.puts "squashfs"
    end

    chroot.image.mkdir "/usr/local/share/initramfs-tools"
    chroot.image.open("/usr/local/share/initramfs-tools/mount_boot") do |f|
      f.puts File.read("#{File.dirname(__FILE__)}/mount_boot.sh")
    end

    chroot.sudo "/usr/sbin/update-initramfs -u"
  end

  @@script_header = <<EOF
#!/bin/sh -x
if [ "$1" == "prereqs" ]; then
  echo ""; exit 0;
fi
EOF

  def install_script(chroot, name, &block)
    install_file(chroot, :script, name, &block)
  end

  def install_hook(chroot, name, &block)
    install_file(chroot, :hook, name) do |f|
      f.puts ". /usr/share/initramfs-tools/hook-functions"
      yield f
    end
  end

  def install_file(chroot, type, name, &block)
    file = "/usr/share/initramfs-tools/#{type}s/#{name}"
    chroot.image.mkdir File.dirname(file)
    chroot.image.open(file) do |f|
      f.puts @@script_header
      yield f
      f.puts "exit 0"
    end
    chroot.sudo "chmod +x #{file}"
  end

end
