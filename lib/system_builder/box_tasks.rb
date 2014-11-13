require 'rake/tasklib'
require 'qemu'

class SystemBuilder::BoxTasks < Rake::TaskLib

  # FIXME we can't count box instances .. the first box doesn't "see" next ones
  @@multiple_boxes = nil
  def self.multiple_boxes=(multiple_boxes)
    @@multiple_boxes = multiple_boxes
  end
  def self.multiple_boxes?
    @@multiple_boxes
  end

  @@multiple_architecture = nil
  def self.multiple_architecture=(multiple_architecture)
    @@multiple_architecture = multiple_architecture
  end
  def self.multiple_architecture?
    @@multiple_architecture
  end

  attr_reader :box

  def initialize(box, &block)
    self.class.init

    @box =
      if Symbol === box
        SystemBuilder::Box.new(box)
      else
        box
      end

    @box.named_mode = self.class.multiple_boxes?
    @box.multi_architecture = self.class.multiple_architecture?

    yield @box if block_given?

    define
  end

  @@initialized = false

  def self.init
    return if @@initialized

    ["#{ENV['HOME']}/.system_builder.rc", "./local.rb"].each do |conf|
      load conf if File.exists?(conf)
    end
    @@initialized = true
    # Dir['tasks/**/*.rake'].each { |t| load t }
  end

  def box_namespace
    [box.name].tap do |parts|
      parts << box.architecture if box.multi_architecture?
    end.join(':')
  end

  def define
    namespace box_namespace do
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

        def initrd_file
          initrd_link = File.expand_path("#{box.root_file}/initrd.img")

          unless File.readable?(initrd_link)
            # Under wheezy, initrd.img is an absolute link like /boot/initrd.img-3.12-0.bpo.1-amd64'"
            read_initrd_link = `readlink #{initrd_link}`.strip
            if read_initrd_link =~ %r{^/(.*)$}
              initrd_link = File.expand_path($1, box.root_file)
            end
          end

          initrd_link
        end

        desc "Create upgrade files"
        task :upgrade do
          rm_rf box.upgrade_directory
          mkdir_p box.upgrade_directory
          ln_s File.expand_path("#{box.build_dir}/filesystem.squashfs"), "#{box.upgrade_directory}/filesystem-#{box.release_name}.squashfs"
          ln_s File.expand_path("#{box.root_file}/vmlinuz"), "#{box.upgrade_directory}/vmlinuz-#{box.release_name}"
          ln_s initrd_file, "#{box.upgrade_directory}/initrd-#{box.release_name}.img"
          FileUtils::sh "tar -cf #{box.upgrade_file} --dereference -C #{box.upgrade_directory} ."

          box.create_latest_file
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

      namespace :storage do

        task :clean do
          rm Dir["#{box.dist_dir}/storage*"]
        end

        def create_disk(name, size, format = "raw")
          suffix = format == "raw" ? "" : ".#{format}"
          filename = "#{box.dist_dir}/#{name}#{suffix}"

          options = { :format => format, :size => size }
          if options[:format].to_s == "qcow2"
            options[:options] = { :preallocation => "metadata", :cluster_size => "2M" }
          end

          QEMU::Image.new(filename, options).create
        end

        desc "Create storage disk"
        task :create, [:disk_count, :size, :format] do |t, args|
          defaults = {
            :disk_count => 1,
            :size => ENV.fetch("STORAGE_SIZE", "2000M"),
            :format => ENV.fetch("STORAGE_FORMAT", "raw"),
          }
          args.with_defaults defaults

          disk_count = args.disk_count.to_i
          puts "Disk count: #{disk_count}"

          if disk_count.to_i > 1
            disk_count.times { |n| create_disk "storage#{n+1}", args.size, args.format }
          else
            create_disk "storage", args.size, args.format
          end
        end

      end

      namespace :vm do
        def vmbox
          box.vmbox
        end

        def start_and_save
          timeout = ENV['TIMEOUT']
          timeout = timeout.to_i if timeout
          vmbox.start_and_save timeout
        end

        task :inspect do
          puts vmbox.inspect
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
          start_and_save
        end

        desc "Save box VM"
        task :save do
          vmbox.save
        end

        desc "Rollback box VM"
        task :rollback do
          vmbox.rollback
        end

        # FIXME : fork qemu and cucumber in the same process
        # makes unreachable the qemu monitor telnet server (?!)
        desc "Launch tests in VM (FIXME)"
        task :test do
          cucumber_task = Rake::Task['cucumber']
          if cucumber_task
            begin
              puts "Start VM ..."
              start_and_save

              puts "Run tests ..."
              cucumber_task.invoke
            ensure
              puts "Stop VM"
              vmbox.stop
            end
          else
            raise "No cucumber task is available"
          end
        end
      end

      namespace :get do
        desc "Retrieve latest build release"
        task :latest do
          release_server = "http://dev.tryphon.priv/dist"
          release_directory = box.name.to_s
          if box.multi_architecture?
            release_directory += "/#{box.architecture}"
          end
          latest_release = `wget -q -O - #{release_server}/#{release_directory}/latest.yml | sed -n '/^name/ s/name: // p'`.strip

          release_filename = latest_release
          if box.multi_architecture?
            release_filename.gsub! box.name.to_s, "#{box.name}-#{box.architecture}"
          end

          puts "Download #{latest_release} to #{box.disk_file}"
          sh "wget -q -c -m -P #{box.dist_dir}/ --no-directories #{release_server}/#{release_directory}/#{release_filename}.disk.gz"
          sh "gunzip -c #{box.dist_dir}/#{latest_release}.disk.gz > #{box.disk_file}"
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

      task :ci => [:clean, "dist:all", "ci:dist"] do
        # clean in dependencies is executed only once
        FileUtils::sh "rake #{box.name}:clean"
      end

      def latest_release_number
        @latest_release_number ||= YAML.load(IO.read(box.latest_file))["name"].gsub("#{box.name}-","") if File.exists?(box.latest_file)
      end

      namespace :ci do
        task :dist do
          target_directory = (ENV['DIST'] or "#{ENV['HOME']}/dist/#{box.release_dir}")
          box.release_number = latest_release_number if latest_release_number

          mkdir_p target_directory
          sh "gzip --fast --stdout #{box.disk_file} > #{target_directory}/#{box.release_filename}.disk.gz"
          cp box.iso_file, "#{target_directory}/#{box.release_filename}.iso"
          cp box.upgrade_file, "#{target_directory}/#{box.release_filename}.tar"

          cp box.latest_file, "#{target_directory}/#{box.release_filename}.yml"
          ln_sf "#{target_directory}/#{box.release_filename}.yml", "#{target_directory}/latest.yml"
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

      desc "Tag and publish latest ci #{box.name} release"
      task :release do
        SystemBuilder::Publisher.new(box.name).publish
      end
    end
  end

end

class SystemBuilder::MultiArchBoxTasks < Rake::TaskLib

  attr_accessor :name, :architectures

  def initialize(name, architectures = [:amd64, :i386], &block)
    @name, @architectures = name, architectures

    SystemBuilder::BoxTasks.multiple_architecture = true

    architectures.each do |architecture|
      SystemBuilder::BoxTasks.new(name) do |box|
        box.architecture = architecture
        yield box if block_given?
      end
    end

    both_tasks "clean", "dist", "dist:all"
    default_architecture_tasks "get:latest", "vm:start", "vm:stop", "vm:start_and_save"

    storage_task
    ci_task
  end

  def default_architecture
    @default_architecture ||= architectures.first
  end

  def default_architecture_task(task)
    desc "#{task} by using #{default_architecture}"
    task "#{name}:#{task}" => "#{name}:#{default_architecture}:#{task}"
  end

  def default_architecture_tasks(*tasks)
    tasks.flatten.each { |task| default_architecture_task task }
  end

  def both_task(task)
    desc "#{task} all architectures"
    architectures.each do |architecture|
      task "#{name}:#{task}" => "#{name}:#{architecture}:#{task}"
    end
  end

  def both_tasks(*tasks)
    tasks.flatten.each { |task| both_task task }
  end

  def storage_task
    desc "Create storage disk by using #{default_architecture}"
    task "#{name}:storage:create", [:disk_count, :size, :format] do |t, args|
      Rake::Task["#{name}:#{default_architecture}:storage:create"].invoke(*args.values)
    end
  end

  def ci_task
    desc "Run continuous integration tasks (spec, ...)"
    task :ci => "#{name}:ci"

    # clean and dist all architectures
    task "#{name}:ci" => ["#{name}:clean", "#{name}:dist:all"]
    # before publishing releases
    architectures.each do |architecture|
      task "#{name}:ci" => "#{name}:#{architecture}:ci:dist"
    end
  end

end
