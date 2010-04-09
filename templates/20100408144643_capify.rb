# Capify

project = File.basename(Dir.pwd).inspect

file "Capfile" do
  <<-EOS
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

# Load custom deploy tasks
Dir['config/deploy/tasks/**/*.rb'].each { |plugin| load(plugin) }

load 'config/deploy' # remove this line to skip loading any of the default tasks
EOS
end

file "config/deploy.rb" do
  <<-EOS
set :application, #{project}
set :user, application

require 'capistrano/ext/multistage'

set :database_user, user
set :scm, :git
set :default_shell, "/bin/bash"

# Disable compression, to circumvent bug that shows:
#  zlib(finalizer): the stream was freed prematurely.
ssh_options[:compression] = "none"

# The use of passenger (mod_rails) obliviates the need for sudo.
set :use_sudo, false

set :scm_username, user
set :repository,  "\#{scm_username}@octo.veridit.no:/home/groups/gits/\#{application}.git"

server "octo.veridit.no", :app, :web, :db, :primary => true

after "deploy:restart" do
  # Fetch the front page to prevent users from getting first slow load.
  run %{curl -s -o /dev/null 'http://\#{rails_env}.\#{application}.veridit.no/'}
end

EOS
end

[:development, :staging, :demo, :production].each do |stage|
  file "config/deploy/#{stage}.rb" do
    <<-EOS
set :rails_env, "#{stage}"
set :deploy_to, "/home/users/\#{user}/\#{rails_env}"
set :default_environment,{"RAILS_ENV"=>rails_env}
EOS
  end
end

file 'config/deploy/tasks/deploy.rb' do
  <<-EOF
# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  after "deploy:setup" do
    # Remove group writability on home directory, or else ssh refuses
    # to log in using keys
    run "chmod g-w \#{deploy_to}/.."
  end

  before "deploy:finalize_update" do
    # Create the public/stylesheets directory necessary for sass to
    # compile into, as all sass stylesheets are kept in app/stylesheets
    run "mkdir -p \#{release_path}/public/stylesheets"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    run "\#{try_sudo} touch \#{File.join(current_path,'tmp','restart.txt')}"
  end

  after  :'deploy',            :'deploy:cleanup'
  after  :'deploy:migrations', :'deploy:cleanup'

  before 'deploy:update_code' do
    unless ENV['tag'] and not ENV['tag'].empty? then
      abort <<-EOS
        Only tag based deployment is supported.
        You can create a git tag like this:
          git tag v1.0
        Then provide the tag explicitly with:
          cap \#{ARGV.join(' ')} tag=v1.0
      EOS
    end
    set :revision, ENV['tag'] 
  end
  desc 'Restore database from local copies from production and reset code to same version as production'
  task :restore_from_production, {:restore_from_production => :environment, :roles => :db} do
    #worker.stop
    db.restore_remote_from_dumped_production
    production_revision = capture("cat ~\#{user}/production/current/REVISION")
    if production_revision != capture("cat \#{current_path}/REVISION")
      ENV['tag'] = production_revision
      find_and_execute_task('deploy')
    end
    #worker.start
  end
end
EOF
end

file 'config/deploy/tasks/db.rb' do
  <<-EOF
desc "Reset code and database from production"  
task :remote_reset_from_production,{:remote_reset_from_production => :environment, :roles => :db } do
  commands = <<-EOS
#!/bin/bash
set -e
cap production db:dump
COMMAND="cp /home/\#{user}/production/current/tmp/\#{application}_production.pgdump \#{current_path}/tmp/" cap \#{rails_env} invoke
cap \#{rails_env} deploy:web:disable REASON="deployment" UNTIL="when the deployment, including restore of fresh database from production, is done"
cap \#{rails_env} deploy:restore_from_production
cap \#{rails_env} deploy:web:enable
  EOS
  filename = "tmp/reset_deployed_staging_from_deployed_production.sh"
  File.open(filename,'w+') do |file|
    file.write commands
  end
  FileUtils.chmod 0o774,filename
  # Notice that it is not possible to run multiple different 
  # environments from the same capistrano task, so instead the
  # commands are batched, and that file is executed.
  exec filename
end

namespace :db do
  desc "Dump the remote database"
  task :dump, {:dump => :environment, :roles => :db} do
    run "rake -f \#{current_path}/Rakefile db:dump"
  end

  desc "Retrieve the previously dumped remote database"
  task :fetch, {:dump => :environment, :roles => :db} do
    config_file = File.join('config','database.yml')
    config_database = YAML.load(ERB.new(IO.read(config_file)).result)
    database = config_database[rails_env]['database']
    # Since there are multiple environments running tibet, we must deduce 
    # the database name from the database_user of the curent environment 
    database = "\#{database_user}_\#{rails_env}"
    get "\#{current_path}/tmp/\#{database}.pgdump", "tmp/\#{database}.pgdump"
  end

  desc "Locally reset the previously dumped and fetched remote database"
  task :reset, :roles => :db do
    system "rake db:restore source_rails_env=\#{rails_env} source_database_user=\#{database_user}"
  end

  desc "Dump and fetch the remote database and restore to the local database."
  task :restore, :roles => :db do
    db.dump
    db.fetch
    db.reset
  end
  task :restore_remote_from_dumped_production, {:restore_remote_from_dumped_production => :environment, :roles => :db} do
    # Close open connections to database, and restore production database .
    # SIGTERM causes postgres self to stop transactions and disconnect clients 
    run %{sudo /usr/bin/pkill -SIGTERM -f ^postgres.*\#{application}_\#{rails_env} || echo "No database connections closed"}
    run %{rake -f \#{current_path}/Rakefile db:restore source_rails_env=production}
  end
end
EOF
end

git :add => "Capfile config/deploy.rb config/deploy"
git :commit => "-m 'Added Capistrano configuration'"
