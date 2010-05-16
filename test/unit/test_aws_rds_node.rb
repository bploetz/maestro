require 'helper'

# Unit tests for Maestro::Node::Aws::Rds
class TestAwsRdsNode < Test::Unit::TestCase

  context "Maestro::Node::Aws::Rds" do
    setup do
      @cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          rds_node "db-1" do
            availability_zone "us-east-1"
            engine "MySQL5.1"
            db_instance_class "db.m1.small"
            master_username "root"
            master_user_password "password"
            port 3306
            allocated_storage 5
            preferred_maintenance_window "Sun:03:00-Sun:07:00"
            backup_retention_period 7
            preferred_backup_window "03:00-05:00"
            db_parameters [{:name => "some_param", :value => "1"},
                           {:name => "some_other_param", :value => "foo"}]
          end
        end
      end
      @node = @cloud.nodes["db-1"]
    end

    should "be an Rds node" do
      assert @node.is_a? Maestro::Node::Aws::Rds
    end

    should "be invalid due to name too long" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          rds_node "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX1234" do end
        end
      end
      node = cloud.nodes["XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX1234"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must be less than 64 characters").nil?}
    end

    should "be invalid due to name containing invalid characters" do
      "!@\#$%^&*()_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        cloud = aws_cloud :test do
          roles {}
          nodes do
            ec2_node "web-1" do end
            rds_node "#{char}" do end
          end
        end
        node = cloud.nodes["#{char}"]
        node.validate
        assert !node.valid?
        assert node.validation_errors.any? {|message| !message.index("name may only contain alphanumerics and hyphens").nil?}
      end
    end

    should "be invalid due to name not starting with a letter" do
      "0123456789!@\#$%^&*()_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        cloud = aws_cloud :test do
          roles {}
          nodes do
            ec2_node "web-1" do end
            rds_node "#{char}" do end
          end
        end
        node = cloud.nodes["#{char}"]
        node.validate
        assert !node.valid?
        assert node.validation_errors.any? {|message| !message.index("name must start with a letter").nil?}
      end
    end

    should "be invalid due to name ending with hyphen" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          rds_node "test-" do end
        end
      end
      node = cloud.nodes["test-"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must not end with a hypen").nil?}
    end

    should "be invalid due to name containing two consecutive hyphens" do
      cloud = aws_cloud :test do
        roles {}
        nodes do
          ec2_node "web-1" do end
          rds_node "te--st" do end
        end
      end
      node = cloud.nodes["te--st"]
      node.validate
      assert !node.valid?
      assert node.validation_errors.any? {|message| !message.index("name must not contain two consecutive hyphens").nil?}
    end

    should "be invalid due to missing availability_zone" do
      @node.availability_zone nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing availability_zone").nil?}
    end

    should "be invalid due to missing db_instance_class" do
      @node.db_instance_class nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing db_instance_class").nil?}
    end

    should "be invalid due to invalid db_instance_class" do
      @node.db_instance_class "foo"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node db_instance_class is invalid").nil?}
    end

    should "be valid db_instance_classes" do
      ["db.m1.small", "db.m1.large", "db.m1.xlarge", "db.m2.2xlarge", "db.m2.4xlarge"].each do |ic|
        @node.validation_errors.clear
        @node.db_instance_class ic
        @node.validate
        assert !@node.validation_errors.any? {|message| !message.index("node db_instance_class is invalid").nil?}
      end
    end

    should "be invalid due to missing engine" do
      @node.engine nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing engine").nil?}
    end

    should "be invalid due to invalid engine" do
      @node.engine "foo"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node engine is invalid").nil?}
    end

    should "be valid engines" do
      ["MySQL5.1"].each do |e|
        @node.validation_errors.clear
        @node.engine e
        @node.validate
        assert !@node.validation_errors.any? {|message| !message.index("node engine is invalid").nil?}
      end
    end

    should "be invalid due to missing master_username" do
      @node.master_username nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing master_username").nil?}
    end

    should "be invalid due to master_username too long" do
      @node.master_username "XXXXXXXXXXXXXXXX"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("master_username must be less than 16 characters").nil?}
    end

    should "be invalid due to master_username not starting with a letter" do
      "0123456789!@\#$%^&*()_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        @node.validation_errors.clear
        @node.master_username "#{char}"
        @node.validate
        assert !@node.valid?
        assert @node.validation_errors.any? {|message| !message.index("master_username must start with a letter").nil?}
      end
    end

    should "be invalid due to master_username containing invalid characters" do
      "!@\#$%^&*()-_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        @node.validation_errors.clear
        @node.master_username "a1#{char}9Z"
        @node.validate
        assert !@node.valid?
        assert @node.validation_errors.any? {|message| !message.index("master_username may only contain alphanumerics").nil?}
      end
    end

    should "be invalid due to missing master_user_password" do
      @node.master_user_password nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing master_user_password").nil?}
    end

    should "be invalid due to master_user_password too short" do
      @node.master_user_password "X"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("master_user_password must be between 4 and 16 characters in length").nil?}
    end

    should "be invalid due to master_user_password too long" do
      @node.master_user_password "XXXXXXXXXXXXXXXXX"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("master_user_password must be between 4 and 16 characters in length").nil?}
    end

    should "be invalid due to master_user_password containing invalid characters" do
      "!@\#$%^&*()-_=+~`\"{[}]\\|/?.>,<".each_char do |char|
        @node.validation_errors.clear
        @node.master_user_password "a1#{char}9Z"
        @node.validate
        assert !@node.valid?
        assert @node.validation_errors.any? {|message| !message.index("master_user_password may only contain alphanumerics").nil?}
      end
    end

    should "be invalid due to missing port" do
      @node.port nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing port").nil?}
    end

    should "be invalid due to port too low" do
      @node.port 1
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("port must be between 1150 and 65535").nil?}
    end

    should "be invalid due to port too high" do
      @node.port 111111
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("port must be between 1150 and 65535").nil?}
    end

    should "be invalid due to port not a number" do
      @node.port false
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("port must be a number").nil?}
    end

    should "be invalid due to missing allocated_storage" do
      @node.allocated_storage nil
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("node missing allocated_storage").nil?}
    end

    should "be invalid due to allocated_storage too low" do
      @node.allocated_storage 1
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("allocated_storage must be between 5 and 1024").nil?}
    end

    should "be invalid due to allocated_storage too high" do
      @node.allocated_storage 1025
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("allocated_storage must be between 5 and 1024").nil?}
    end

    should "be invalid due to allocated_storage not a number" do
      @node.allocated_storage false
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("allocated_storage must be a number").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window start day value" do
      @node.preferred_maintenance_window "FOO:15:00-Sun:09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window start hour value" do
      @node.preferred_maintenance_window "Tue:25:00-Sun:09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window start minute value" do
      @node.preferred_maintenance_window "FOO:25:60-Sun:09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window end day value" do
      @node.preferred_maintenance_window "Sun:15:00-Bar:09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window end hour value" do
      @node.preferred_maintenance_window "Tue:03:30-Tue:29:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_maintenance_window end minute value" do
      @node.preferred_maintenance_window "Sat:03:00-Sat:03:345"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_maintenance_window must be in UTC format 'ddd:hh24:mi-ddd:hh24:mi'").nil?}
    end

    should "be invalid due to backup_retention_period too low" do
      @node.backup_retention_period -1
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("backup_retention_period must be between 0 and 8").nil?}
    end

    should "be invalid due to backup_retention_period too high" do
      @node.backup_retention_period 9
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("backup_retention_period must be between 0 and 8").nil?}
    end

    should "be invalid due to backup_retention_period not a number" do
      @node.backup_retention_period false
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("backup_retention_period must be a number").nil?}
    end

    should "be invalid due to incorrect preferred_backup_window start hour value" do
      @node.preferred_backup_window "25:00-09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_backup_window must be in UTC format 'hh24:mi-hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_backup_window start minute value" do
      @node.preferred_backup_window "03:60-09:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_backup_window must be in UTC format 'hh24:mi-hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_backup_window end hour value" do
      @node.preferred_backup_window "03:00-28:00"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_backup_window must be in UTC format 'hh24:mi-hh24:mi'").nil?}
    end

    should "be invalid due to incorrect preferred_backup_window end minute value" do
      @node.preferred_backup_window "03:00-05:60"
      @node.validate
      assert !@node.valid?
      assert @node.validation_errors.any? {|message| !message.index("preferred_backup_window must be in UTC format 'hh24:mi-hh24:mi'").nil?}
    end

    should "be valid" do
      @node.validate
      assert @node.valid?
      assert @node.validation_errors.empty?
    end
  end
end
