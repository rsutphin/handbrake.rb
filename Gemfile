source :rubygems

# Specify your gem's dependencies in handbrake.gemspec
gemspec

group :development do
  # For yard's markdown support
  platforms :jruby do
    gem 'maruku'
  end

  platforms :ruby_18, :ruby_19 do
    gem 'rdiscount'
  end
end
