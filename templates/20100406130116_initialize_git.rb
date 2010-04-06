# Initialize git
unless File.exists?('.git')
  system 'git', 'init'
  system 'git', 'commit', '--allow-empty', '-m', 'Initial Commit'
end
