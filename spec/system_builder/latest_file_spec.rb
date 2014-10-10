require 'spec_helper'

describe SystemBuilder::LatestFile do

  describe "#commit" do
    it "should contain the latest git commit" do
      subject.commit.should =~ /^[a-f0-9]+$/
    end
  end
  
end
