require 'tempfile'

class SystemBuilder::IsoImage

  attr_accessor :boot
  attr_reader :file

  def initialize(file)
    @file = file
  end

  def create
    boot.create
    create_iso

    self
  end

  def create_iso
    install_isolinux_files
    make_iso_fs
  end

  def install_isolinux_files(options = {})
    root = (options[:root] or "/dev/hdc")
    version = (options[:version] or Time.now.strftime("%Y%m%d%H%M"))

    boot.image do |image|
      image.mkdir "/boot/isolinux"

      image.open("/boot/isolinux/isolinux.cfg") do |f|
        f.puts "default linux"
        f.puts "label linux"
        f.puts "kernel /vmlinuz"
        f.puts "append ro root=#{root} initrd=/initrd.img"
      end

      image.install "/boot/isolinux", "/usr/lib/syslinux/isolinux.bin"
    end
  end

  def readlink_boot_file(boot_file)
    File.basename(%x{readlink #{boot.root}/#{boot_file}}.strip)
  end

  def make_iso_fs
    FileUtils::sudo "genisoimage -quiet -R -o #{file} -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -A #{root_fs_label} -V #{root_fs_label} -graft-points -hide build/root/initrd.img -hide build/root/vmlinuz vmlinuz=#{boot.root}/boot/#{readlink_boot_file('vmlinuz')} initrd.img=#{boot.root}/boot/#{readlink_boot_file('initrd.img')} #{boot.root}"
    FileUtils::sudo "chown $USER #{file}"
  end

  def root_fs_label
    "root"
  end

end
