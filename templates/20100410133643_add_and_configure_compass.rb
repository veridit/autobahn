# Adapted from 

# Add and configure compass
gem "haml", :version => ">= 2.2.16"
gem "compass", :version => ">= 0.10.0.pre5"
gem 'fancy-buttons', :version => '>= 0.3.7'
git :add => "config/environment.rb"

# install and unpack
rake "gems:install GEM=haml"
rake "gems:unpack GEM=haml"
rake "gems:install GEM=compass"
rake "gems:unpack GEM=compass"
rake "gems:install GEM=fancy-buttons"
rake "gems:unpack GEM=fancy-buttons"
git :add => "vendor/gems"

# Require compass during plugin loading
file 'vendor/plugins/compass/init.rb', <<-CODE
# This is here to make sure that the right version of sass gets loaded (haml 2.2) by the compass requires.
require 'compass'
CODE
git :add => 'vendor/plugins/compass/init.rb'

git :commit => '-m "Added compass"'

# Set it up
run "haml --rails ."
run "compass --rails -f blueprint . --css-dir=public/stylesheets/compiled --sass-dir=app/stylesheets"

gsub_file 'config/compass.rb', /\z/m, <<-EOF
require 'compass-colors'
require 'fancy-buttons'
EOF

git :add => 'vendor/plugins/haml config/initializers/compass.rb config/compass.rb public/images/grid.png'
git :commit => '-m "Configured compass"'

# Clear out the compass generated stylesheets and replace them with our own
run 'find app/stylesheets -type f -print0 | xargs --null rm'
skel 'app/stylesheets'
git :add => 'app/stylesheets'
git :commit => '-m "Stubbed out structure for compass stylesheets"'
