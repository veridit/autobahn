# Initialize git
unless File.exists?('.git')
  capture 'git', 'init'
  capture 'git', 'commit', '--allow-empty', '-m', 'Initial Commit'
end
