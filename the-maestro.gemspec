# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{the-maestro}
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Brian Ploetz"]
  s.date = %q{2010-10-05}
  s.description = %q{Maestro is a cloud provisioning, configuration, and management utility for your Ruby and Ruby On Rails applications.}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/maestro.rb",
     "lib/maestro/cloud.rb",
     "lib/maestro/cloud/aws.rb",
     "lib/maestro/dsl_property.rb",
     "lib/maestro/log4r/console_formatter.rb",
     "lib/maestro/log4r/file_formatter.rb",
     "lib/maestro/node.rb",
     "lib/maestro/operating_system.rb",
     "lib/maestro/operating_system/cent_os.rb",
     "lib/maestro/operating_system/debian.rb",
     "lib/maestro/operating_system/fedora.rb",
     "lib/maestro/operating_system/ubuntu.rb",
     "lib/maestro/role.rb",
     "lib/maestro/tasks.rb",
     "lib/maestro/validator.rb",
     "rails/init.rb",
     "test/integration/base_aws.rb",
     "test/integration/fixtures/config/maestro/cookbooks/emacs/metadata.json",
     "test/integration/fixtures/config/maestro/cookbooks/emacs/metadata.rb",
     "test/integration/fixtures/config/maestro/cookbooks/emacs/recipes/default.rb",
     "test/integration/fixtures/config/maestro/roles/default.json",
     "test/integration/fixtures/config/maestro/roles/web.json",
     "test/integration/helper.rb",
     "test/integration/test_aws_cloud.rb",
     "test/integration/test_cent_os.rb",
     "test/integration/test_debian.rb",
     "test/integration/test_fedora.rb",
     "test/integration/test_ubuntu.rb",
     "test/unit/fixtures/invalid-clouds-not-a-directory/config/maestro/clouds",
     "test/unit/fixtures/invalid-cookbooks-not-a-directory/config/maestro/cookbooks",
     "test/unit/fixtures/invalid-maestro-not-a-directory/config/maestro",
     "test/unit/fixtures/invalid-missing-cookbooks/config/maestro/clouds/valid.yml",
     "test/unit/fixtures/invalid-missing-roles/config/maestro/clouds/valid.yml",
     "test/unit/fixtures/invalid-roles-not-a-directory/config/maestro/roles",
     "test/unit/fixtures/ssh/id_rsa-maestro-test-keypair",
     "test/unit/helper.rb",
     "test/unit/test_aws_cloud.rb",
     "test/unit/test_aws_ec2_node.rb",
     "test/unit/test_aws_elb_node.rb",
     "test/unit/test_aws_rds_node.rb",
     "test/unit/test_cent_os.rb",
     "test/unit/test_cloud.rb",
     "test/unit/test_configurable_node.rb",
     "test/unit/test_debian.rb",
     "test/unit/test_fedora.rb",
     "test/unit/test_invalid_mode.rb",
     "test/unit/test_maestro.rb",
     "test/unit/test_node.rb",
     "test/unit/test_operating_system.rb",
     "test/unit/test_rails_mode.rb",
     "test/unit/test_role.rb",
     "test/unit/test_standalone_mode.rb",
     "test/unit/test_ubuntu.rb",
     "the-maestro.gemspec"
  ]
  s.homepage = %q{http://github.com/bploetz/maestro}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Maestro: Conduct your clouds.}
  s.test_files = [
    "test/integration/base_aws.rb",
     "test/integration/fixtures/config/maestro/cookbooks/emacs/metadata.rb",
     "test/integration/fixtures/config/maestro/cookbooks/emacs/recipes/default.rb",
     "test/integration/helper.rb",
     "test/integration/test_aws_cloud.rb",
     "test/integration/test_cent_os.rb",
     "test/integration/test_debian.rb",
     "test/integration/test_fedora.rb",
     "test/integration/test_ubuntu.rb",
     "test/unit/helper.rb",
     "test/unit/test_aws_cloud.rb",
     "test/unit/test_aws_ec2_node.rb",
     "test/unit/test_aws_elb_node.rb",
     "test/unit/test_aws_rds_node.rb",
     "test/unit/test_cent_os.rb",
     "test/unit/test_cloud.rb",
     "test/unit/test_configurable_node.rb",
     "test/unit/test_debian.rb",
     "test/unit/test_fedora.rb",
     "test/unit/test_invalid_mode.rb",
     "test/unit/test_maestro.rb",
     "test/unit/test_node.rb",
     "test/unit/test_operating_system.rb",
     "test/unit/test_rails_mode.rb",
     "test/unit/test_role.rb",
     "test/unit/test_standalone_mode.rb",
     "test/unit/test_ubuntu.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, ["= 2.10.2"])
      s.add_runtime_dependency(%q<net-ssh>, ["= 2.0.15"])
      s.add_runtime_dependency(%q<net-scp>, ["= 1.0.2"])
      s.add_runtime_dependency(%q<net-ssh-multi>, ["= 1.0.1"])
      s.add_runtime_dependency(%q<net-ssh-gateway>, ["= 1.0.1"])
      s.add_runtime_dependency(%q<archive-tar-minitar>, ["= 0.5.2"])
      s.add_runtime_dependency(%q<amazon-ec2>, ["= 0.9.11"])
      s.add_runtime_dependency(%q<aws-s3>, ["= 0.6.2"])
      s.add_runtime_dependency(%q<log4r>, ["= 1.1.7"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, ["= 2.10.2"])
      s.add_dependency(%q<net-ssh>, ["= 2.0.15"])
      s.add_dependency(%q<net-scp>, ["= 1.0.2"])
      s.add_dependency(%q<net-ssh-multi>, ["= 1.0.1"])
      s.add_dependency(%q<net-ssh-gateway>, ["= 1.0.1"])
      s.add_dependency(%q<archive-tar-minitar>, ["= 0.5.2"])
      s.add_dependency(%q<amazon-ec2>, ["= 0.9.11"])
      s.add_dependency(%q<aws-s3>, ["= 0.6.2"])
      s.add_dependency(%q<log4r>, ["= 1.1.7"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, ["= 2.10.2"])
    s.add_dependency(%q<net-ssh>, ["= 2.0.15"])
    s.add_dependency(%q<net-scp>, ["= 1.0.2"])
    s.add_dependency(%q<net-ssh-multi>, ["= 1.0.1"])
    s.add_dependency(%q<net-ssh-gateway>, ["= 1.0.1"])
    s.add_dependency(%q<archive-tar-minitar>, ["= 0.5.2"])
    s.add_dependency(%q<amazon-ec2>, ["= 0.9.11"])
    s.add_dependency(%q<aws-s3>, ["= 0.6.2"])
    s.add_dependency(%q<log4r>, ["= 1.1.7"])
  end
end

