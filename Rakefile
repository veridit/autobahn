require 'rake/clean'

CLOBBER << Rake::FileList["autobahn-*.gem"]

task :gem do
  sh 'gem', 'build', 'autobahn.gemspec'
end
