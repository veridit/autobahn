# Add rake tasks

[:db, :test].each do
  rakefile "#{task}.rake", File.read(File.join(autobahn_repo, 'skel', 'lib', 'tasks', "#{task}.rake"))
  git :add => "lib/tasks/#{task}.rake"
end

git :commit => "-m 'Added rake tasks'"
