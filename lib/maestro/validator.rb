module Maestro
  # The Validator mixin provides methods for performing validation and reporting validation errors
  module Validator

    # whether this object is valid or not. defaults to true
    attr :valid
    # the collection of validation error strings. if valid is false, this should contain details as to why the object is invalid
    attr_reader :validation_errors

    def initialize
      @validation_errors = Array.new
      @valid = true
    end

    # calls the validate_internal method, which classes including this Module should implement
    def validate
      validate_internal
    end

    # returns whether this object is valid or not
    def valid?
      @valid
    end

    # sets this object's valid attribute to false, and records the given
    # validation error string in the validation_errors attribute
    def invalidate(error_str)
      @valid = false
      @validation_errors << error_str
    end
  end
end
