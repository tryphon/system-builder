require 'rake/tasklib'

class SystemBuilder::BoxTasks < Rake::TaskLib

  # FIXME we can't count box instances .. the first box doesn't "see" next ones
  @@multiple_boxes = nil
  def self.multiple_boxes=(multiple_boxes)
    @@multiple_boxes = multiple_boxes
  end
  def self.multiple_boxes?
    @@multiple_boxes
  end

  attr_reader :box

  def initialize(box, &block)
    init

    @box =
      if Symbol === box
        SystemBuilder::Box.new(box)
      else
        box
      end

    @box.named_mode = self.class.multiple_boxes?

    yield @box if block_given?

    define
  end

  def init
    ["#{ENV['HOME']}/.system_builder.rc", "./local.rb"].each do |conf|
      load conf if File.exists?(conf)
    end

    Dir['tasks/**/*.rake'].each { |t| load t }
  end

  def define
    namespace box.name do
      desc "Create disk/iso images"

      desc "Shortcut for dist:disk task"
      task :dist => "dist:disk"

      task :inspect do
        puts box.inspect
      end

      namespace :dist do
        desc "Create disk image in #{box.disk_file}"
        task :disk do
          box.disk_image.create
        end

        desc "Create iso image in #{@iso_file}"
        task :iso do
          box.iso_image.create
        end

        desc "Create NFS image in #{@nfs_file}"
        task :nfs do
          box.nfs_image.create
        end

        desc "Create upgrade files"
        task :upgrade do
          rm_rf box.upgrade_directory
          mkdir_p box.upgrade_directory
          ln_s File.expand_path("#{box.build_dir}/filesystem.squashfs"), "#{box.upgrade_directory}/filesystem-#{box.release_name}.squashfs"
          ln_s File.expand_path("#{box.root_file}/vmlinuz"), "#{box.upgrade_directory}/vmlinuz-#{box.release_name}"
          ln_s File.expand_path("#{box.root_file}/initrd.img"), "#{box.upgrade_directory}/initrd-#{box.release_name}.img"
          FileUtils::sh "tar -cf #{box.upgrade_file} --dereference -C #{box.upgrade_directory} ."

          box.create_latest_file "#{box.dist_dir}/latest.yml"
        end

        desc "Create all images (disk, iso and upgrade)"
        task :all => [:disk, :iso, :upgrade]
      end

      namespace :build do
        desc "Configure the image system"
        task :configure do
          box.boot.configure
          box.boot.clean
        end

        desc "Clean the image system"
        task :clean do
          box.boot.clean
        end
      end

      namespace :vm do
        def vmbox
          box.vmbox
        end

        desc "Start box VM"
        task :start do
          vmbox.start
        end

        desc "Reset box VM"
        task :reset do
          vmbox.reset
        end

        desc "Stop box VM"
        task :stop do
          vmbox.stop
        end

        desc "Start and save box VM"
        task :start_and_save do
          timeout = ENV['TIMEOUT']
          timeout = timeout.to_i if timeout
          vmbox.start_and_save timeout
        end

        desc "Save box VM"
        task :save do
          vmbox.save
        end

        desc "Rollback box VM"
        task :rollback do
          vmbox.rollback
        end
      end

      desc "Clean build and dist directories"
      task :clean do
        unless File.exists?(box.root_file) and system "sudo fuser $PWD/#{box.root_file}"
          sudo "rm -rf #{box.root_file}"
        end
        FileUtils::sh "rm -rf #{box.upgrade_directory}"
        FileUtils::sh "rm -f #{box.build_dir}/*"
        FileUtils::sh "rm -rf #{box.dist_dir}/*"
      end

      task :buildbot => [:clean, "dist:all", "buildbot:dist"] do
        # clean in dependencies is executed only once
        FileUtils::sh "rake #{box.name}:clean"
      end

      def latest_release_number
        YAML.load(IO.read(box.latest_file))["name"].gsub("#{box.name}-","") if File.exists?(box.latest_file)
      end

      namespace :buildbot do
        task :dist do
          target_directory = (ENV['DIST'] or "#{ENV['HOME']}/dist/#{box.name}")
          release_number = (latest_release_number or box.release_number)

          mkdir_p target_directory
          sh "gzip --fast --stdout #{box.disk_file} > #{target_directory}/#{box.name}-#{release_number}.disk.gz"
          cp box.iso_file, "#{target_directory}/#{box.name}-#{release_number}.iso"
          cp box.upgrade_file, "#{target_directory}/#{box.name}-#{release_number}.tar"

          cp box.latest_file, "#{target_directory}/latest.yml"
        end
      end

      desc "Setup your environment to build an image"
      task :setup do
        if ENV['WORKING_DIR']
          %w{build dist}.each do |subdir|
            working_subdir = File.join ENV['WORKING_DIR'], subdir
            unless File.exists?(working_subdir)
              puts "* create and link #{working_subdir}"
              mkdir_p working_subdir
            end
            ln_sf working_subdir, subdir unless File.exists?(subdir)
          end
        end
      end

      desc "Tag and publish latest buildbot #{box.name} release"
      task :release do
        SystemBuilder::Publisher.new(box.name).publish
      end
    end
  end

end
