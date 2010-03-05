require 'rake/tasklib'

class SystemBuilder::Task < Rake::TaskLib

  attr_reader :name

  def initialize(name, &block)
    @name = name

    @image =
      if block_given?
        block.call
      else
        SystemBuilder.config(name)
      end

    define
  end

  def define
    namespace name do
      desc "Create image #{name} in #{@image.file}"
      task :dist do
        @image.create
      end
      namespace :dist do
        desc "Create vmwaire image in #{@image.file}.vdmk"
        task :vmware do
          @image.convert "#{@image.file}.vmdk", :format => "vmdk"
        end
      end
      task "dist:vmware" => "dist"

      namespace :build do
        desc "Configure the image system"
        task :configure do
          @image.boot.configure
          @image.boot.clean
        end

        desc "Clean the image system"
        task :clean do
          @image.boot.clean
        end
      end

      task :setup do
        required_packages = []
        required_packages << "qemu" # to convert image files
        required_packages << "util-linux" # provides sfdisk
        required_packages << "sudo"
        required_packages << "debootstrap"
        required_packages << "rsync"
        required_packages << "dosfstools"
        required_packages << "syslinux"
        
        FileUtils.sudo "apt-get install #{required_packages.join(' ')}"
      end
    end
  end

end
