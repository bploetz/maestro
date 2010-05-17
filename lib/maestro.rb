require "maestro/dsl_property"
require "find"
require "ftools"
require "maestro/cloud"
require "maestro/cloud/aws"
require "maestro/operating_system"


def aws_cloud(name, &block)
  Maestro::Cloud::Aws.new(name, &block)
end


module Maestro

  # ENV key used to point to a Maestro configuration directory
  MAESTRO_DIR_ENV_VAR = 'MAESTRO_DIR'

  # Directory underneath RAILS_ROOT where Maestro expects to find config files
  MAESTRO_RAILS_CONFIG_DIRECTORY = '/config/maestro'

  # Directory underneath RAILS_ROOT where Maestro log files will be written
  MAESTRO_RAILS_LOG_DIRECTORY = '/log/maestro'

  # Name of the Maestro Chef assets archive
  MAESTRO_CHEF_ARCHIVE = 'maestro_chef_assets.tar.gz'


  # Creates the Maestro config directory structure. If the directories already exist, no action is taken.
  #
  # In a Rails environment:
  #
  #     RAILS_ROOT/config/maestro
  #     RAILS_ROOT/config/maestro/clouds
  #     RAILS_ROOT/config/maestro/cookbooks
  #     RAILS_ROOT/config/maestro/roles
  #
  # In a standalone environment, the following directories will be created under
  # the directory specified by the ENV['MAESTRO_DIR'] environment variable:
  #
  #     MAESTRO_DIR/config/maestro
  #     MAESTRO_DIR/config/maestro/clouds
  #     MAESTRO_DIR/config/maestro/cookbooks
  #     MAESTRO_DIR/config/maestro/roles
  def self.create_config_dirs
    if defined? RAILS_ROOT
      create_configs(rails_config_dir)
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      create_configs(standalone_config_dir)
    else
      raise "Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"
    end
  end

  # Creates the Maestro log directories. If the directories already exist, no action is taken.
  #
  # In a Rails environment:
  #
  #     RAILS_ROOT/log/maestro
  #     RAILS_ROOT/log/maestro/clouds
  #
  # In a standalone environment, the following directories will be created under
  # the directory specified by the ENV['MAESTRO_DIR'] environment variable:
  #
  #     MAESTRO_DIR/log/maestro
  #     MAESTRO_DIR/log/maestro/clouds
  def self.create_log_dirs
    if defined? RAILS_ROOT
      create_logs(rails_log_dir)
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      create_logs(standalone_log_dir)
    else
      raise "Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"
    end
  end

  # Validates your maestro configs. This method returns an Array with two elements:
  # * element[0] boolean indicating whether your maestro configs are valid
  # * element[1] Array of Strings containing a report of the validation
  def self.validate_configs
    if defined? RAILS_ROOT
      validate_rails_config
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      validate_standalone_config
    else
      return [false, ["Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"]]
    end
  end

  # Returns a Hash of Clouds defined in the Maestro clouds configuration directory
  def self.clouds
    if defined? RAILS_ROOT
      get_clouds(clouds_config_dir(rails_config_dir))
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      get_clouds(clouds_config_dir(standalone_config_dir))
    else
      raise "Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"
    end
  end

  # Returns the log directory
  def self.log_directory
    if defined? RAILS_ROOT
      rails_config_dir
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      standalone_config_dir
    else
      raise "Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"
    end
  end

  # Creates a .tar.gz file containing the Chef cookbooks/ and roles/ directories within the maestro config directory, and returns the path to the file
  def self.chef_archive
    require 'tempfile'
    require 'zlib'
    require 'archive/tar/minitar'

    dir = nil
    if defined? RAILS_ROOT
      dir = rails_config_dir
    elsif ENV.has_key? MAESTRO_DIR_ENV_VAR
      dir = standalone_config_dir
    else
      raise "Maestro not configured correctly. Either RAILS_ROOT or ENV['#{MAESTRO_DIR_ENV_VAR}'] must be defined"
    end
    temp_file = Dir.tmpdir + "/" + MAESTRO_CHEF_ARCHIVE
    File.delete(temp_file) if File.exist?(temp_file)

    pwd = Dir.pwd
    open temp_file, 'wb' do |io|
      Zlib::GzipWriter.wrap io do |gzip|
        begin
          out = Archive::Tar::Minitar::Output.new(gzip)
          Dir.chdir(dir) # don't store full paths in archive
          Dir.glob("cookbooks/**/**").each do |file|
            Archive::Tar::Minitar.pack_file(file, out) if File.file?(file) || File.directory?(file) 
          end
          Dir.glob("roles/**/**").each do |file|
            Archive::Tar::Minitar.pack_file(file, out) if File.file?(file) || File.directory?(file) 
          end
        ensure
          gzip.finish
        end
      end
    end
    Dir.chdir(pwd)
    temp_file
  end


  private

  # Creates the Maestro config directory structure in the given directory
  #
  # - dir: The base directory in which to create the maestro config directory structure
  def self.create_configs(dir)
    raise "Cannot create Maestro config directory structure: #{dir} doesn't exist." if !File.exist?(dir)
    raise "Cannot create Maestro config directory structure: #{dir} is not a directory." if !File.directory?(dir)
    raise "Cannot create Maestro config directory structure: #{dir} is not writable." if !File.writable?(dir)
    base_dir = dir
    base_dir.chop! if base_dir =~ /\/$/
    if File.exist?("#{base_dir}/maestro")
      puts "#{base_dir}/maestro already exists"
    else
      Dir.mkdir("#{base_dir}/maestro")
      puts "Created #{base_dir}/maestro"
    end
    if File.exist?("#{base_dir}/maestro/clouds")
      puts "#{base_dir}/maestro/clouds already exists"
    else
      Dir.mkdir("#{base_dir}/maestro/clouds")
      puts "Created #{base_dir}/maestro/clouds"
    end
    if File.exist?("#{base_dir}/maestro/cookbooks")
      puts "#{base_dir}/maestro/cookbooks already exists"
    else
      Dir.mkdir("#{base_dir}/maestro/cookbooks")
      puts "Created #{base_dir}/maestro/cookbooks"
    end
    if File.exist?("#{base_dir}/maestro/roles")
      puts "#{base_dir}/maestro/roles already exists"
    else
      Dir.mkdir("#{base_dir}/maestro/roles")
      puts "Created #{base_dir}/maestro/roles"
    end
  end

  # Creates the Maestro config directory structure in the given directory
  #
  # - dir: The base directory in which to create the maestro log directory structure
  def self.create_logs(dir)
    raise "Cannot create Maestro log directory: #{dir} doesn't exist." if !File.exist?(dir)
    raise "Cannot create Maestro log directory: #{dir} is not a directory." if !File.directory?(dir)
    raise "Cannot create Maestro log directory: #{dir} is not writable." if !File.writable?(dir)
    base_dir = dir
    base_dir.chop! if base_dir =~ /\/$/
    if File.exist?("#{base_dir}/maestro")
      puts "#{base_dir}/maestro already exists"
    else
      Dir.mkdir("#{base_dir}/maestro")
      puts "Created #{base_dir}/maestro"
    end
    if File.exist?("#{base_dir}/maestro/clouds")
      puts "#{base_dir}/maestro/clouds already exists"
    else
      Dir.mkdir("#{base_dir}/maestro/clouds")
      puts "Created #{base_dir}/maestro/clouds"
    end
  end

  # Validates the maestro configuration found at RAILS_ROOT/config/maestro
  def self.validate_rails_config
    validate_config rails_maestro_config_dir
  end

  # Validates the maestro configuration found at ENV['MAESTRO_DIR']
  def self.validate_standalone_config
    validate_config standalone_maestro_config_dir
  end

  # Validates the maestro configuration found at the given maestro_directory
  def self.validate_config(maestro_directory)
    valid = true
    error_messages = Array.new
    if !File.exist?(maestro_directory)
      valid = false
      error_messages << "Maestro config directory does not exist: #{maestro_directory}"
    end
    if !File.directory?(maestro_directory)
      valid = false
      error_messages << "Maestro config directory is not a directory: #{maestro_directory}"
    end
    clouds_directory = clouds_config_dir maestro_directory
    if !File.exist?(clouds_directory)
      valid = false
      error_messages << "Maestro clouds config directory does not exist: #{clouds_directory}"
    end
    if !File.directory?(clouds_directory)
      valid = false
      error_messages << "Maestro clouds config directory is not a directory: #{clouds_directory}"
    end
    cookbooks_directory = cookbooks_dir maestro_directory
    if !File.exist?(cookbooks_directory)
      valid = false
      error_messages << "Chef cookbooks directory does not exist: #{cookbooks_directory}"
    else
      if !File.directory?(cookbooks_directory)
        valid = false
        error_messages << "Chef cookbooks directory is not a directory: #{cookbooks_directory}"
      end
    end
    roles_directory = roles_dir maestro_directory
    if !File.exist?(roles_directory)
      valid = false
      error_messages << "Chef roles directory does not exist: #{roles_directory}"
    else
      if !File.directory?(roles_directory)
        valid = false
        error_messages << "Chef roles directory is not a directory: #{roles_directory}"
      end
    end
    if valid
      clouds = get_clouds(clouds_directory)
      clouds.each do |name, cloud|
        cloud.validate
        if !cloud.valid?
          valid = false
          error_messages << "INVALID: #{cloud.config_file}"
          cloud.validation_errors.each {|error| error_messages << "    #{error}"}
        else
          error_messages << "VALID: #{cloud.config_file}"
        end
      end
    end
    return [valid, error_messages]
  end

  def self.rails_config_dir
    "#{RAILS_ROOT}/config"
  end

  def self.rails_log_dir
    "#{RAILS_ROOT}/log"
  end

  def self.rails_maestro_config_dir
    "#{RAILS_ROOT}#{MAESTRO_RAILS_CONFIG_DIRECTORY}"
  end

  def self.standalone_maestro_config_dir
    "#{ENV[MAESTRO_DIR_ENV_VAR]}#{MAESTRO_RAILS_CONFIG_DIRECTORY}"
  end

  def self.standalone_config_dir
    "#{ENV[MAESTRO_DIR_ENV_VAR]}/config"
  end

  def self.standalone_log_dir
    "#{ENV[MAESTRO_DIR_ENV_VAR]}/log"
  end

  def self.clouds_config_dir(maestro_directory)
    "#{maestro_directory}/clouds"
  end

  def self.cookbooks_dir(maestro_directory)
    "#{maestro_directory}/cookbooks"
  end

  def self.roles_dir(maestro_directory)
    "#{maestro_directory}/roles"
  end

  # Gets the Hash of Clouds found in clouds_directory
  def self.get_clouds(clouds_directory)
    clouds_directory << "/" unless clouds_directory =~ /\/$/
    clouds = {}
    config_files = get_cloud_config_files(clouds_directory)
    config_files.each do |config_file|
      cloud_name = config_file[clouds_directory.length, (config_file.length-(clouds_directory.length+File.extname(config_file).length))]
      cloud = Cloud::Base.create_from_file(config_file)
      clouds[cloud_name] = cloud
    end
    clouds
  end

  # Returns and array of all Cloud files found in clouds_directory
  def self.get_cloud_config_files(clouds_directory)
    config_files = []
    Find.find(clouds_directory) do |path|
      if FileTest.file?(path) && (File.extname(path).eql?(".rb"))
        config_files << path
      end
    end
    config_files
  end
end
