require 'rake/clean'

CLOBBER << Rake::FileList["autobahn-*.gem"]

task :gem do
  sh 'gem', 'build', 'autobahn.gemspec'
end

namespace :gem do
  task :push => :gem do
    sh 'gem', 'push', "autobahn-#{%x{git describe --tag}.chomp.sub(/^v/, '')}.gem"
  end
end
