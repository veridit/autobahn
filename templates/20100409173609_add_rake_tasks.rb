# Add rake tasks

[:db, :test].each do
  rakefile "#{task}.rake", File.read(File.join(autobahn_repo, 'skel', 'lib', 'tasks', "#{task}.rake"))
  git :add => "lib/tasks/#{task}.rake"
end

['script/generate_pg_restore_gis_ltree_pg_trgm_intarray_cleanup.rb',
 'script/pg_restore_gis_ltree_pg_trgm_intarray_cleanup.rb'].each do |path|
  file path, File.read(File.join(autobahn_repo, 'skel', path))
  run 'chmod', '+x', path
  git :add => path
end

git :commit => "-m 'Added rake tasks'"
