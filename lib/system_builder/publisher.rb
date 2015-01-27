module SystemBuilder
  class Publisher
    attr_accessor :box
    attr_accessor :build_server, :dist_directory, :www_server, :download_dir

    def initialize(box)
      @box = box

      @build_server = "dev.tryphon.priv"
      @dist_directory = "/var/www/dist"
      @www_server = "www.tryphon.priv"
      @download_dir = "/var/www/tryphon.eu/download"
    end

    def latest_attributes
      @latest_attributes ||= YAML.load(`ssh #{build_server} cat #{dist_directory}/#{box_directory}/latest.yml`)
    end

    def release_name
      latest_attributes["name"]
    end

    def release_filename
      latest_attributes["url"].gsub /.tar$/, ""
    end

    def commit
      latest_attributes["commit"] or ENV['COMMIT']
    end

    def box_directory
      [].tap do |parts|
        parts << box.name
        parts << box.architecture if box.multi_architecture?
      end.join('/')
    end

    def source_directory
      "#{dist_directory}/#{box_directory}"
    end

    def target_directory
      "#{download_dir}/#{box_directory}"
    end

    def publish
      raise "Select a git commit with COMMIT=... (see buildbot at http://dev.tryphon.priv:8010/builders/#{box.name}/)" unless commit
      puts "Publish last release : #{release_name} (commit #{commit})"

      FileUtils::sh "ssh #{www_server} 'mkdir -p #{target_directory}'"

      FileUtils::sh "scp '#{build_server}:#{source_directory}/#{release_filename}*' #{www_server}:#{target_directory}"
      FileUtils::sh "ssh #{www_server} 'cd #{target_directory} && ln -fs #{release_filename}.yml latest.yml'"

      if `git show-ref --tags`.split.grep("refs/tags/#{release_name}").empty?
        FileUtils::sh "git tag -a #{release_name} -m 'Release #{release_name}' #{commit}"
        FileUtils::sh "git push --tags"
      end
    end
  end
end
