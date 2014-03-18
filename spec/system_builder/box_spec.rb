require 'spec_helper'

describe SystemBuilder::Box do

  subject { SystemBuilder::Box.new :test }

  describe "#latest_file" do
    it "should a yml file in dist_dir named with release name" do
      subject.latest_file.should == "dist/latest.yml"
    end
  end

end
