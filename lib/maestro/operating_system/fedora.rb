module Maestro
  module OperatingSystem
    # The Fedora Linux distro
    class Fedora < Base
      def initialize(etc_issue_str)
        super(etc_issue_str)
        @chef_install_script =
          ["sudo rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-3.noarch.rpm",
           "sudo rpm -Uvh http://download.elff.bravenet.com/5/i386/elff-release-5-3.noarch.rpm",
           "sudo yum install -y ruby ruby-shadow ruby-ri ruby-rdoc gcc gcc-c++ ruby-devel",
           "sudo mkdir -p /usr/local/src",
           "sudo wget -P /usr/local/src http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz",
           "sudo tar zxf /usr/local/src/rubygems-1.3.6.tgz -C /usr/local/src",
           "sudo ruby /usr/local/src/rubygems-1.3.6/setup.rb",
           "sudo rm /usr/local/src/rubygems-1.3.6.tgz",
           "sudo gem sources -a http://gems.opscode.com",
           "sudo gem install rake --no-rdoc --no-ri",
           "sudo gem install chef --no-rdoc --no-ri --version '= 0.8.14'",
           "sudo ln -sfv $(gem environment gemdir)/gems/chef-0.8.14/bin/chef-solo /usr/bin/chef-solo"]
      end
    end
  end
end
