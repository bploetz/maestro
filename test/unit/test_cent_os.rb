require 'helper'

# Unit tests for Maestro::OperatingSystem::CentOs
class TestCentOs < Test::Unit::TestCase

  context "Maestro::OperatingSystem::CentOs" do
    setup do
    end

    context "CentOS" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("CentOS")
        assert os.instance_of? Maestro::OperatingSystem::CentOs
      end

      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("CentOS")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("CentOS")
        assert os.respond_to? :etc_issue_string
      end
    end

  end
end