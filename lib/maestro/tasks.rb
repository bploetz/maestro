require "maestro"

namespace :maestro do

  desc "Creates the Maestro config directory structure. If the directories already exist, no action is taken."
  task :create_config_dirs do
    Maestro.validate_configs
  end

  desc "Validates your Maestro configuration files"
  task :validate_configs do
    result = Maestro.validate_configs
    result[1].each {|msg| puts msg}
  end

  if !Maestro.clouds.nil? && !Maestro.clouds.empty?
    Maestro.clouds.each_pair do |cloud_name, cloud|
      if cloud.valid?
        namespace "#{cloud_name}" do
          desc "Reports the status of the #{cloud_name} cloud"
          task "status" do |t|
            cloud.status
          end

          desc "Ensures that the #{cloud_name} cloud is running as currently configured"
          task "start" do |t|
            cloud.start
          end

          desc "Configures the nodes in the #{cloud_name} cloud. This installs Chef and runs your Chef recipes on the node."
          task "configure" do |t|
            cloud.configure
          end

          desc "Shuts down the #{cloud_name} cloud"
          task "shutdown" do |t|
            cloud.shutdown
          end

          if cloud.is_a?(Maestro::Cloud::Aws) && !cloud.rds_nodes.empty?
            cloud.rds_nodes.each_pair do |name, node|
              desc "Reboots the #{name} RDS node. Make sure you put up the appropriate maintanance pages first."
              task "reboot-#{name}" do |t|
                cloud.reboot_rds_node(name)
              end
            end
          end
        end
      end
    end
  end
end
