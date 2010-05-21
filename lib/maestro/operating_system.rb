module Maestro
  module OperatingSystem
    # Reads the given string containing the contents of <code>/etc/issue</code> and returns
    # an OperatingSystem object matching the Linux version. Raises an exception
    # if the operating system cannot be determined or is unsupported by Maestro.
    def self.create_from_etc_issue(etc_issue_str)
      raise StandardError, "Invalid etc_issue_str" if (etc_issue_str.nil? || etc_issue_str.empty?)
      if etc_issue_str.include?("Ubuntu 10.04")
        Ubuntu1004.new(etc_issue_str)
      elsif etc_issue_str.include?("Ubuntu 9.10")
        Ubuntu910.new(etc_issue_str)
      elsif etc_issue_str.include?("Ubuntu 9.04")
        Ubuntu904.new(etc_issue_str)
      elsif etc_issue_str.include?("Ubuntu 8.10")
        Ubuntu810.new(etc_issue_str)
      elsif etc_issue_str.include?("Ubuntu 8.04")
        Ubuntu804.new(etc_issue_str)
      elsif etc_issue_str.include?("Ubuntu")
        Ubuntu.new(etc_issue_str)
      elsif etc_issue_str.include?("Debian GNU/Linux 6.0")
        Debian6.new(etc_issue_str)
      elsif etc_issue_str.include?("Debian GNU/Linux 5.0")
        Debian5.new(etc_issue_str)
      elsif  etc_issue_str.include?("Debian")
        Debian.new(etc_issue_str)
      elsif etc_issue_str.include?("Fedora")
        Fedora.new(etc_issue_str)
      elsif  etc_issue_str.include?("CentOS")
        CentOs.new(etc_issue_str)
      else
        raise StandardError, "ERROR: Unsupported Linux Distro: #{etc_issue_str}"
      end
    end

    
    # An operating system
    class Base
      @name
      @version
      @etc_issue_string
      @chef_install_script
  
      attr_reader :name, :version, :etc_issue_string, :chef_install_script
  
      def initialize(etc_issue_string)
        @etc_issue_string = etc_issue_string
      end
    end
  end
end

require "maestro/operating_system/cent_os"
require "maestro/operating_system/debian"
require "maestro/operating_system/fedora"
require "maestro/operating_system/ubuntu"
