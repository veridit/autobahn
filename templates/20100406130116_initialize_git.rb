# Initialize git
unless File.exists?('.git')
  run 'git', 'init'
  run 'git', 'commit', '--allow-empty', '-m', 'Initial Commit'
end
