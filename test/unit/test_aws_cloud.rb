require 'helper'

# Unit tests for Maestro::Cloud::Aws
class TestAwsCloud < Test::Unit::TestCase

  context "Maestro::Cloud::Aws" do
    setup do
      @cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
        aws_account_id "XXXX-XXXX-XXXX"
        aws_access_key "XXXXXXXXXXXXXXXXXXXX"
        aws_secret_access_key "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        chef_bucket "maestro.mydomain.com"

        roles do
          role "web" do
            public_ports [80, 443]
          end
        end

        nodes do
          ec2_node "web-1" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
            elastic_ip "111.111.11.111"
            ebs_volume_id "vol-XXXXXXXX"
            ebs_device "/dev/sdh"
          end
        end
      end
    end

    should "be invalid due to duplicate ec2 nodes" do
      cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
        aws_account_id "XXXX-XXXX-XXXX"
        aws_access_key "XXXXXXXXXXXXXXXXXXXX"
        aws_secret_access_key "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        chef_bucket "maestro.mydomain.com"

        roles {}

        nodes do
          ec2_node "web-1" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
            elastic_ip "111.111.11.111"
            ebs_volume_id "vol-XXXXXXXX"
            ebs_device "/dev/sdh"
          end
          ec2_node "web-1" do
            roles ["web"]
            ami "ami-bb709dd2"
            ssh_user "ubuntu"
            instance_type "m1.small"
            availability_zone "us-east-1b"
            elastic_ip "111.111.11.111"
            ebs_volume_id "vol-XXXXXXXX"
            ebs_device "/dev/sdh"
          end
        end
      end
      cloud.validate
      assert !cloud.valid?
      assert cloud.validation_errors.any? {|message| !message.index("Duplicate node definition: web-1").nil?}
    end

    should "be invalid due to duplicate elb nodes" do
      cloud = aws_cloud :test do
        keypair_name "XXXXXXX-keypair"
        keypair_file "/path/to/id_rsa-XXXXXXX-keypair"
        aws_account_id "XXXX-XXXX-XXXX"
        aws_access_key "XXXXXXXXXXXXXXXXXXXX"
        aws_secret_access_key "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
        chef_bucket "maestro.mydomain.com"

        roles {}

        nodes do
          elb_node "lb-1" do
          end
          elb_node "lb-1" do
          end
        end
      end
      cloud.validate
      assert !cloud.valid?
      assert cloud.validation_errors.any? {|message| !message.index("Duplicate node definition: lb-1").nil?}
    end

    should "be invalid due to missing aws access key" do
      @cloud.aws_access_key nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing aws_access_key").nil? }
    end

    should "be invalid due to missing aws account id" do
      @cloud.aws_account_id nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing aws_account_id").nil? }
    end

    should "be invalid due to missing aws secret access key" do
      @cloud.aws_secret_access_key nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing aws_secret_access_key").nil? }
    end

    should "be invalid due to missing chef bucket" do
      @cloud.chef_bucket nil
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Missing chef_bucket").nil? }
    end

    should "be invalid due to invalid region name" do
      @cloud.region "foo"
      @cloud.validate
      assert !@cloud.valid?
      assert @cloud.validation_errors.any? {|message| !message.index("Invalid region").nil? }
    end

    should "be valid" do
      @cloud.validate
      assert @cloud.valid?
      assert @cloud.validation_errors.empty?
    end
  end
end
