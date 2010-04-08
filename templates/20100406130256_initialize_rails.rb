# Initialize rails
run 'ruby', File.join('vendor', 'rails', 'railties', 'bin', 'rails'), Dir.pwd, '--git'
run 'git', 'commit', '-m', "Initialized rails"
