namespace :test do
  task :syntax do
    command = "git ls-files --full-name | grep -ie '\\.rb$' | grep -ve '^vendor' | xargs -n 1 ruby -c >/dev/null"
    puts "Executing #{command}"
    system command
  end
end
