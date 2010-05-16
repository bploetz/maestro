require "helper"
require "etc"
require "AWS"
require "aws/s3"

# Base AWS contectivity
module BaseAws

  #
  # BE CAREFUL!
  #
  # A poorly written test will cost you and others money. The onus is on you to double check
  # that you don't orphan EC2 instances, S3 buckets/objects, Elastic IPs, RDS instances,
  # ELBs, EBS Volumes/Snapshots, etc. The AWS Console is your friend.
  #
  # To be safe, create a new keypair just for use with running these tests. Don't use
  # an existing keypair associated with any sensitive production data!
  #
  # To run the integration tests, place a file named maestro_tests_aws_credentials.rb
  # in your home directory, with the following Hash:
  #
  #   {
  #     # The name of the keypair to use to authenticate with AWS, start instances, etc 
  #     :keypair_name => "XXXXXXX-keypair",
  #   
  #     # Path to the keypair file matching the :keypair_name
  #     :keypair_file => "/path/to/your/id_rsa-XXXXXXX-keypair",
  #   
  #     # Your AWS Account ID
  #     :aws_account_id => "XXXX-XXXX-XXXX",
  #   
  #     # Your AWS Access Key
  #     :aws_access_key => "XXXXXXXXXXXXXXXXXXXX",
  #   
  #     # Your AWS Secret Access Key
  #     :aws_secret_access_key => "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  #   
  #     # Name of the S3 bucket to store Chef assets in
  #     :chef_bucket => "maestro-tests-aws.XXXXXXXX.com"
  #  }
  #
  # Make sure you set the appropriate permissions on this file, and delete it when you're done running the integration tests.
  #


  #######################
  # Setup
  #######################
  def setup
    @config_file_name = 'maestro_tests_aws_credentials.rb'
    @maestro_aws_credentials = Etc.getpwuid.dir + "/#{@config_file_name}"
    raise "Missing Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}." if !File.exists?(@maestro_aws_credentials)
    raise "Cannot read Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}." if !File.readable?(@maestro_aws_credentials)
    @credentials = eval(File.read(@maestro_aws_credentials))
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Does not contain a Hash" if !@credentials.instance_of?(Hash)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :keypair_name key" if !@credentials.has_key?(:keypair_name)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :keypair_file key" if !@credentials.has_key?(:keypair_file)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :aws_account_id key" if !@credentials.has_key?(:aws_account_id)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :aws_access_key key" if !@credentials.has_key?(:aws_access_key)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :aws_secret_access_key key" if !@credentials.has_key?(:aws_secret_access_key)
    raise "Invalid Maestro::Cloud::Aws integration test config file: ~/#{@config_file_name}. Missing :chef_bucket key" if !@credentials.has_key?(:chef_bucket)

    @ec2 = AWS::EC2::Base.new(:access_key_id => @credentials[:aws_access_key], :secret_access_key => @credentials[:aws_secret_access_key], :use_ssl => true)
    @elb = AWS::ELB::Base.new(:access_key_id => @credentials[:aws_access_key], :secret_access_key => @credentials[:aws_secret_access_key], :use_ssl => true)
    @rds = AWS::RDS::Base.new(:access_key_id => @credentials[:aws_access_key], :secret_access_key => @credentials[:aws_secret_access_key], :use_ssl => true)
    AWS::S3::Base.establish_connection!(:access_key_id => @credentials[:aws_access_key], :secret_access_key => @credentials[:aws_secret_access_key], :use_ssl => true)

    # keep track of the Elastic IPs we started with
    before_addresses = @ec2.describe_addresses()
    @before_elastic_ips = Array.new
    if !before_addresses.addressesSet.nil?
      before_addresses.addressesSet.item.each {|item| @before_elastic_ips << item.publicIp}
    end

    # keep track of the EBS volumes we started with
    before_volumes = @ec2.describe_volumes()
    @before_volumes = Array.new
    if !before_volumes.volumeSet.nil?
      before_volumes.volumeSet.item.each {|item| @before_volumes << item.volumeId if !item.status.eql? "deleting"}
    end

    # keep track of the S3 Buckets we started with
    before_buckets = AWS::S3::Service.buckets
    @before_buckets = Array.new
    if !before_buckets.empty?
      before_buckets.each {|bucket| @before_buckets << bucket.name}
    end
  end


  #######################
  # Teardown
  #######################

  def teardown
    # release elastic ips
    after_addresses = @ec2.describe_addresses()
    @after_elastic_ips = Array.new
    if !after_addresses.addressesSet.nil?
      after_addresses.addressesSet.item.each {|item| @after_elastic_ips << item.publicIp}
    end
    @before_elastic_ips.each do |before_elastic_ip|
      found = @after_elastic_ips.find {|after_elastic_ip| after_elastic_ip.eql?(before_elastic_ip)}
      puts "ERROR! AWS integration test error: It appears an Elastic IP address associated with the account before the integration tests ran has been released. This should not happen." if !found
    end
    @after_elastic_ips.each do |after_elastic_ip|
      found = @before_elastic_ips.find {|before_elastic_ip| before_elastic_ip.eql?(after_elastic_ip)}
      if !found
        puts "Releasing AWS integration test Elastic IP: #{after_elastic_ip}"
        @ec2.release_address(:public_ip => after_elastic_ip)
      end
    end

    # delete EBS volumes
    after_volumes = @ec2.describe_volumes()
    @after_volumes = Array.new
    if !after_volumes.volumeSet.nil?
      after_volumes.volumeSet.item.each {|item| @after_volumes << item.volumeId if !item.status.eql? "deleting"}
    end
    @before_volumes.each do |before_volume|
      found = @after_volumes.find {|after_volume| after_volume.eql?(before_volume)}
      puts "ERROR! AWS Cloud integration test error: It appears an EBS volume associated with the account before the integration tests ran has been deleted. This should not happen." if !found
    end
    @after_volumes.each do |after_volume|
      found = @before_volumes.find {|before_volume| before_volume.eql?(after_volume)}
      if !found
        puts "Deleting AWS integration test EBS Volume: #{after_volume}"
        @ec2.delete_volume(:volume_id => after_volume)
      end
    end

    # delete S3 buckets
    after_buckets = AWS::S3::Service.buckets
    @after_buckets = Array.new
    if !after_buckets.empty?
      after_buckets.each {|bucket| @after_buckets << bucket.name}
    end
    @before_buckets.each do |before_bucket_name|
      found = @after_buckets.find {|after_bucket_name| after_bucket_name.eql?(before_bucket_name)}
      puts "ERROR! AWS Cloud integration test error: It appears an S3 Bucket belonging to the account before the integration tests ran has been deleted. This should not happen." if !found
    end
    @after_buckets.each do |after_bucket_name|
      found = @before_buckets.find {|before_bucket_name| before_bucket_name.eql?(after_bucket_name)}
      if !found
        puts "Deleting all objects in S3 Bucket: #{after_bucket_name}"
        bucket = AWS::S3::Bucket.find(after_bucket_name)
        bucket.delete_all
        puts "Deleting S3 Bucket: #{after_bucket_name}"
        bucket.delete
      end
    end

    ENV.delete Maestro::MAESTRO_DIR_ENV_VAR
  end

end
