require 'rake/clean'

CLEAN << "autobahn-#{File.read('VERSION').chomp}.gem"

task :gem do
  sh 'gem', 'build', 'autobahn.gemspec'
end
