require 'helper'

# Unit tests for Maestro::OperatingSystem::Fedora
class TestFedora < Test::Unit::TestCase

  context "Maestro::OperatingSystem::Fedora" do
    setup do
    end

    context "Fedora" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Fedora")
        assert os.instance_of? Maestro::OperatingSystem::Fedora
      end

      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Fedora")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Fedora")
        assert os.respond_to? :etc_issue_string
      end
    end

  end
end