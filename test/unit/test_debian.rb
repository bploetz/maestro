require 'helper'

# Unit tests for Maestro::OperatingSystem::Debian
class TestDebian < Test::Unit::TestCase

  context "Maestro::OperatingSystem::Debian" do
    setup do
    end

    context "Debian 6.0" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 6.0")
        assert os.instance_of? Maestro::OperatingSystem::Debian6
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 6.0")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 6.0")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Debian 5.0" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 5.0")
        assert os.instance_of? Maestro::OperatingSystem::Debian5
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 5.0")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian GNU/Linux 5.0")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Debian" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian")
        assert os.instance_of? Maestro::OperatingSystem::Debian
      end

      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Debian")
        assert os.respond_to? :etc_issue_string
      end
    end

  end
end