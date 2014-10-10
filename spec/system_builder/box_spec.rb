require 'spec_helper'

describe SystemBuilder::Box do

  subject { SystemBuilder::Box.new :test }

  describe "#latest_file" do
    it "should a yml file in dist_dir named with release name" do
      subject.latest_file.should == "dist/latest.yml"
    end
  end

  describe "#working_directory" do

    it "should use type by default" do
      subject.working_directory(:dummy).should == "dummy"
    end

    it "should add Box name in named_mode" do
      subject.named_mode = true
      subject.working_directory(:dummy).should == "dummy/test"
    end

    it "should add architecture in multi_architecture mode" do
      subject.named_mode = true
      subject.multi_architecture = true
      subject.working_directory(:dummy).should == "dummy/test/amd64"
    end
    
  end

end
