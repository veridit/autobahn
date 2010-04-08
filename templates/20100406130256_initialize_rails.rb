# Initialize rails
capture 'ruby', File.join('vendor', 'rails', 'railties', 'bin', 'rails'), Dir.pwd, '--git'
capture 'git', 'commit', '-m', "Initialized rails"
