require 'spec_helper'

describe SystemBuilder::DebianBoot do
  
  it "should include debian-archive-keyring package by default" do
    SystemBuilder::DebianBoot.new("/dummy").include.should include("debian-archive-keyring")
  end

end
