##
# @see file:README.md
# @see CLI The main class
module HandBrake
  autoload :VERSION, 'handbrake/version'

  autoload :CLI,     'handbrake/cli'
  autoload :Disc,    'handbrake/disc'
  autoload :Title,   'handbrake/disc'
  autoload :Titles,  'handbrake/disc'
  autoload :Chapter, 'handbrake/disc'

  ##
  # The exception thrown when a file exists that shouldn't.
  #
  # @see CLI#output
  class FileExistsError < StandardError; end;
end
