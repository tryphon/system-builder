require 'spec_helper'

describe SystemBuilder::Box do

  let(:box) { SystemBuilder::Box.new :test }
  subject { box }

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

  describe "#external_release_number" do

    subject { box.external_release_number }

    context "when BOX_RELEASE_NUMBER isn't defined" do
      it { should be_nil }
    end

    after { ENV['BOX_RELEASE_NUMBER'] = nil }

    context "when BOX_RELEASE_NUMBER hasn't the expected format (%Y%m%d-%H%M)" do
      before { ENV['BOX_RELEASE_NUMBER'] = 'dummy' }
      it { should be_nil }
    end

    context "when BOX_RELEASE_NUMBER has the expected format (%Y%m%d-%H%M)" do
      before { ENV['BOX_RELEASE_NUMBER'] = '20150112-0724' }
      it { should == ENV['BOX_RELEASE_NUMBER'] }
    end

  end

  describe "#default_release_number" do

    it "shoud return the current Time with this format : %Y%m%d-%H%M" do
      Time.stub now: Time.parse("2015-01-12 07:25:44 +0100")
      SystemBuilder::Box.default_release_number.should == "20150112-0725"
    end

  end

  describe "#release_number" do

    it "should be default_number .. by default" do
      subject.release_number.should == SystemBuilder::Box.default_release_number
    end

    it "should be external_release_number if available" do
      subject.stub external_release_number: "dummy"
      subject.release_number.should == subject.external_release_number
    end

  end

end
