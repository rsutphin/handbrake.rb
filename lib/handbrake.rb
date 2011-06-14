##
# @see file:README.md
# @see CLI The main class
module HandBrake
  autoload :VERSION, 'handbrake/version'

  autoload :CLI,     'handbrake/cli'
  autoload :Titles,  'handbrake/titles'
  autoload :Title,   'handbrake/titles'
  autoload :Chapter, 'handbrake/titles'
end
