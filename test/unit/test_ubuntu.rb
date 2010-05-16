require 'helper'

# Unit tests for Maestro::OperatingSystem::Ubuntu
class TestUbuntu < Test::Unit::TestCase

  context "Maestro::OperatingSystem::Ubuntu" do
    setup do
    end

    context "Ubuntu 9.10" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.10")
        assert os.instance_of? Maestro::OperatingSystem::Ubuntu910
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.10")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.10")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Ubuntu 9.04" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.04")
        assert os.instance_of? Maestro::OperatingSystem::Ubuntu904
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.04")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 9.04")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Ubuntu 8.10" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.10")
        assert os.instance_of? Maestro::OperatingSystem::Ubuntu810
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.10")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.10")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Ubuntu 8.04" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.04")
        assert os.instance_of? Maestro::OperatingSystem::Ubuntu804
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.04")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu 8.04")
        assert os.respond_to? :etc_issue_string
      end
    end

    context "Ubuntu" do
      should "create from etc/issue string" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu")
        assert os.instance_of? Maestro::OperatingSystem::Ubuntu
      end
  
      should "respond to chef_install_script" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu")
        assert os.respond_to? :chef_install_script
      end

      should "respond to etc_issue_str" do
        os = Maestro::OperatingSystem.create_from_etc_issue("Ubuntu")
        assert os.respond_to? :etc_issue_string
      end
    end
  end
end