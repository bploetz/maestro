module Maestro
  module OperatingSystem
    # The Debian Linux distro
    class Debian < Base
      def initialize(etc_issue_str)
        super(etc_issue_str)
        # TODO: Fix Perl locale warnings. They don't appear to effect anything, but are very noisy
        @chef_install_script =
          ["sh -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; apt-get upgrade -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; apt-get install -y sudo'", # http://wiki.debian.org/sudo
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get install -y ruby irb ri rdoc libyaml-ruby and libzlib-ruby build-essential libopenssl-ruby ruby1.8-dev wget'",
           "sudo mkdir -p /usr/local/src",
           "sudo wget -P /usr/local/src http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz",
           "sudo tar zxf /usr/local/src/rubygems-1.3.6.tgz -C /usr/local/src",
           "sudo ruby /usr/local/src/rubygems-1.3.6/setup.rb",
           "sudo rm /usr/local/src/rubygems-1.3.6.tgz",
           "sudo ln -sfv /usr/bin/gem1.8 /usr/bin/gem",
           "sudo gem sources -a http://gems.opscode.com",
           "sudo gem install rake --no-rdoc --no-ri",
           "sudo gem install chef --no-rdoc --no-ri --version '= 0.9.0'",
           "sudo ln -sfv $(gem environment gemdir)/gems/chef-0.9.0/bin/chef-solo /usr/bin/chef-solo"]
      end
    end

    # The Debian 6.0 Linux distro
    class Debian6 < Debian
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end

    # The Debian 5.0 Linux distro
    class Debian5 < Debian
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end
  end
end