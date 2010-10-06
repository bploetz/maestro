require 'rails'
require "active_model/railtie"

module Maestro
  class Railtie < Rails::Railtie
    rake_tasks do
      load "maestro/tasks.rb"
    end
  end
end
