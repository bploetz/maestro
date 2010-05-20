require "log4r"

# Custom Log4r formatter for the console
class ConsoleFormatter < Log4r::BasicFormatter

  def initialize(hash={})
    super(hash)
  end

  def format(logevent)
    if Log4r::LNAMES[logevent.level].eql? "PROGRESS"
      # Formats the data as is with no newline, to allow progress bars to be logged.
      sprintf("%s", logevent.data.to_s)
    else
      format_object(logevent.data) + "\n"
    end
  end
end
