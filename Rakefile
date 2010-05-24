require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "the-maestro"
    gem.summary = %Q{Maestro: Conduct your clouds.}
    gem.description = %Q{Maestro is a cloud provisioning, configuration, and management utility for your Ruby and Ruby On Rails applications.}
    gem.homepage = "http://github.com/bploetz/maestro"
    gem.authors = ["Brian Ploetz"]
    gem.add_development_dependency "thoughtbot-shoulda", "= 2.10.2"
    gem.add_dependency "net-ssh", "= 2.0.15"
    gem.add_dependency "net-scp", "= 1.0.2"
    gem.add_dependency "net-ssh-multi", "= 1.0.1"
    gem.add_dependency "net-ssh-gateway", "= 1.0.1"
    gem.add_dependency "archive-tar-minitar", "= 0.5.2"
    gem.add_dependency "amazon-ec2", "= 0.9.11"
    gem.add_dependency "aws-s3", "= 0.6.2"
    gem.add_dependency "log4r", "= 1.1.7"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

desc 'Run all unit and integration tests'
task :test do
  errors = %w(test:units test:integration).collect do |task|
    begin
      Rake::Task[task].invoke
      nil
    rescue => e
      task
    end
  end.compact
  abort "Errors running #{errors.to_sentence(:locale => :en)}!" if errors.any?
end

require 'rake/testtask'
namespace :test do
  Rake::TestTask.new(:units) do |test|
    test.libs << 'lib' << 'test/unit'
    test.pattern = 'test/unit/test_*.rb'
    test.verbose = true
  end
  
  Rake::TestTask.new(:integration) do |test|
    test.libs << 'lib' << 'test/integration'
    test.pattern = 'test/integration/test_*.rb'
    test.verbose = true
  end

  namespace :integration do
    Rake::TestTask.new(:aws) do |test|
      test.libs << 'lib' << 'test/integration'
      test.pattern = 'test/integration/test_aws_cloud.rb'
      test.verbose = true
    end

    Rake::TestTask.new(:ubuntu) do |test|
      test.libs << 'lib' << 'test/integration'
      test.pattern = 'test/integration/test_ubuntu.rb'
      test.verbose = true
    end

    Rake::TestTask.new(:debian) do |test|
      test.libs << 'lib' << 'test/integration'
      test.pattern = 'test/integration/test_debian.rb'
      test.verbose = true
    end

    Rake::TestTask.new(:fedora) do |test|
      test.libs << 'lib' << 'test/integration'
      test.pattern = 'test/integration/test_fedora.rb'
      test.verbose = true
    end

    Rake::TestTask.new(:centos) do |test|
      test.libs << 'lib' << 'test/integration'
      test.pattern = 'test/integration/test_cent_os.rb'
      test.verbose = true
    end
  end
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'lib' << 'test/units' << 'test/integration'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  files = ['README.rdoc', 'LICENSE', 'lib/**/*.rb']

  rdoc.rdoc_dir = 'rdoc'
  rdoc.options << "-A Module.dsl_property"
  rdoc.main = 'README.rdoc'
  rdoc.title = "Maestro #{version}"
  rdoc.rdoc_files.include('LICENSE', 'README.rdoc', 'lib/**/*.rb')
end
