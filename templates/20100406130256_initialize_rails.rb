# Initialize rails
system 'ruby', File.join('vendor', 'rails', 'railties', 'bin', 'rails'), Dir.pwd, '--git'
system 'git', 'commit', '-m', "Initialized rails"
