module Maestro
  module OperatingSystem
    # Base Ubuntu Linux Distro Class
    class Ubuntu < Base
      def initialize(etc_issue_str)
        super(etc_issue_str)
        @chef_install_script =
          ["sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get update -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get upgrade -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get install -y ruby irb ri rdoc libyaml-ruby and libzlib-ruby build-essential libopenssl-ruby ruby1.8-dev wget'",
           "sudo mkdir -p /usr/local/src",
           "sudo wget -P /usr/local/src http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz",
           "sudo tar zxf /usr/local/src/rubygems-1.3.6.tgz -C /usr/local/src",
           "sudo ruby /usr/local/src/rubygems-1.3.6/setup.rb",
           "sudo rm /usr/local/src/rubygems-1.3.6.tgz",
           "sudo ln -sfv /usr/bin/gem1.8 /usr/bin/gem",
           "sudo gem sources -a http://gems.opscode.com",
           "sudo gem install rake --no-rdoc --no-ri",
           "sudo gem install chef --no-rdoc --no-ri --version '= 0.8.14'",
           "sudo ln -sfv $(gem environment gemdir)/gems/chef-0.8.14/bin/chef-solo /usr/bin/chef-solo"]
      end
    end

    # The Ubuntu 10.04 Linux distro
    class Ubuntu1004 < Ubuntu
      def initialize(etc_issue_str)
        super(etc_issue_str)
        # http://alestic.com/2009/11/ec2-karmic-desktop#comment-237
        @chef_install_script =
          ["sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get update -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo -E apt-get upgrade -y'",
           "sh -c 'export DEBIAN_FRONTEND=noninteractive; sudo apt-get install -y ruby irb ri rdoc libyaml-ruby and libzlib-ruby build-essential libopenssl-ruby ruby1.8-dev wget'",
           "sudo mkdir -p /usr/local/src",
           "sudo wget -P /usr/local/src http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz",
           "sudo tar zxf /usr/local/src/rubygems-1.3.6.tgz -C /usr/local/src",
           "sudo ruby /usr/local/src/rubygems-1.3.6/setup.rb",
           "sudo rm /usr/local/src/rubygems-1.3.6.tgz",
           "sudo ln -sfv /usr/bin/gem1.8 /usr/bin/gem",
           "sudo gem sources -a http://gems.opscode.com",
           "sudo gem install rake --no-rdoc --no-ri",
           "sudo gem install chef --no-rdoc --no-ri --version '= 0.8.14'",
           "sudo ln -sfv $(gem environment gemdir)/gems/chef-0.8.14/bin/chef-solo /usr/bin/chef-solo"]
      end
    end

    # The Ubuntu 9.10 Linux distro
    class Ubuntu910 < Ubuntu
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end


    # The Ubuntu 9.04 Linux distro
    class Ubuntu904 < Ubuntu
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end


    # The Ubuntu 8.10 Linux distro
    class Ubuntu810 < Ubuntu
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end


    # The Ubuntu 8.04 Linux distro
    class Ubuntu804 < Ubuntu
      def initialize(etc_issue_str)
        super(etc_issue_str)
      end
    end
  end
end
