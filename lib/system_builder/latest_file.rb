class SystemBuilder::LatestFile

  attr_accessor :box
  
  def initialize(box)
    @box = box
  end

  delegate :upgrade_file, :release_filename, :release_name, :to => :box

  def upgrade_checksum
    @upgrade_checksum ||= `sha256sum #{upgrade_file}`.split.first
  end

  def commit
    @commit ||= `git log -1 --pretty=format:'%H'`
  end

  def create(latest_file)
    File.open(latest_file, "w") do |f|
      f.puts "name: #{release_name}"
      f.puts "url: #{release_filename}.tar"
      f.puts "checksum: #{upgrade_checksum}"
      f.puts "commit: #{commit}" unless commit.blank?
      f.puts "status_updated_at: #{Time.now}"
      f.puts "description_url: http://www.tryphon.eu/release/#{release_name}"
    end
  end

end
