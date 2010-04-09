# Add rake tasks

rakefile 'db.rake', <<-RAKEFILE
Rake::TaskManager.class_eval do
  def remove_task(task_name)
    @tasks.delete(task_name.to_s)
  end
end

Rake.application.remove_task(:'db:structure:dump')
Rake.application.remove_task(:'db:test:clone_structure')

namespace :db do
  def create_database(config)
      case config['adapter']
      when 'postgresql'
        ensure_template_gis_ltree_pg_trgm_intarray_exists
        @encoding = config[:encoding] || ENV['CHARSET'] || 'utf8'
        begin
          ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres' , 'schema_search_path' => 'public'))
          ActiveRecord::Base.connection.create_database(config['database'] , config.merge('lc_collate'=>'nb_NO.UTF-8','lc_ctype'=>'nb_NO.UTF-8','encoding' => @encoding ,'template' => 'template_gis_ltree_pg_trgm_intarray'))
          ActiveRecord::Base.establish_connection(config)
        rescue
          $stderr.puts $!, *($!.backtrace)
          $stderr.puts "Couldn't create database for \#{config.inspect}"
        end
      else
        raise "gis_ltree_pg_trgm_intarray enabled task not supported by '\#{abcs["test"]["adapter"]}'"
      end
    end

  namespace :structure do
    desc "Dump the database structure to a SQL file"
    task :dump => :environment do
      abcs = ActiveRecord::Base.configurations
      case abcs[RAILS_ENV]["adapter"]
      when "postgresql"
        ENV['PGHOST']     = abcs[RAILS_ENV]["host"] if abcs[RAILS_ENV]["host"]
        ENV['PGPORT']     = abcs[RAILS_ENV]["port"].to_s if abcs[RAILS_ENV]["port"]
        ENV['PGPASSWORD'] = abcs[RAILS_ENV]["password"].to_s if abcs[RAILS_ENV]["password"]
        search_path = abcs[RAILS_ENV]["schema_search_path"]
        search_path = "--schema=\#{search_path}" if search_path
        %x{pg_dump --ignore-version --username="\#{abcs[RAILS_ENV]["username"]}" --schema-only --no-acl --no-owner --format=custom --file=db/\#{RAILS_ENV}_structure.pgdump \#{search_path} \#{abcs[RAILS_ENV]["database"]}}
        raise "Error dumping database" if $?.exitstatus == 1
      else
        raise "gis_ltree_pg_trgm_intarray enabled task not supported by '\#{abcs["test"]["adapter"]}'"
      end

      if ActiveRecord::Base.connection.supports_migrations?
        %x{pg_dump --ignore-version --username="\#{abcs[RAILS_ENV]["username"]}" --data-only --table=\#{ActiveRecord::Migrator.schema_migrations_table_name} --file=db/\#{RAILS_ENV}_migrations.sql \#{search_path} \#{abcs[RAILS_ENV]["database"]}}
      end
    end
  end
  namespace :test do
    desc "Recreate the test databases from the development structure"
    task :clone_structure => [ "db:structure:dump", "db:test:purge" ] do
      abcs = ActiveRecord::Base.configurations
      case abcs["test"]["adapter"]
      when "postgresql"
        ENV['PGHOST']     = abcs["test"]["host"] if abcs["test"]["host"]
        ENV['PGPORT']     = abcs["test"]["port"].to_s if abcs["test"]["port"]
        ENV['PGPASSWORD'] = abcs["test"]["password"].to_s if abcs["test"]["password"]

        %x{pg_restore --list --file=\#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pglist_with_postgis_ltree_pg_trgm_intarray \#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pgdump}
        %x{\#{RAILS_ROOT}/script/pg_restore_gis_ltree_pg_trgm_intarray_cleanup.rb < \#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pglist_with_postgis_ltree_pg_trgm_intarray > \#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pglist_without_postgis_ltree_pg_trgm_intarray}
        %x{pg_restore -U "\#{abcs["test"]["username"]}" --use-list \#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pglist_without_postgis_ltree_pg_trgm_intarray --single-transaction --no-acl --no-owner --dbname \#{abcs["test"]["database"]} \#{RAILS_ROOT}/db/\#{RAILS_ENV}_structure.pgdump}

        %x{psql -U "\#{abcs["test"]["username"]}" -f \#{RAILS_ROOT}/db/\#{RAILS_ENV}_migrations.sql \#{abcs["test"]["database"]}}
      else
        raise "gis_ltree_pg_trgm_intarray enabled task not supported by '\#{abcs["test"]["adapter"]}'"
      end
    end
  end

  desc %{Env needed for psql. Do "eval $(rake --silent db:show_env)".}
  task :show_env => :set_pg_env do
    %w{PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD}.each do|name|
      puts %{export \#{name}=\#{ENV[name]}}
    end
  end

  desc "Set the needed environment variables for command line tools to connect to postgres"
  task :set_pg_env => :environment do
    arbc = ActiveRecord::Base.configurations
    ENV['PGHOST']     = arbc[RAILS_ENV]["host"] if arbc[RAILS_ENV]["host"]
    ENV['PGPORT']     = arbc[RAILS_ENV]["port"].to_s if arbc[RAILS_ENV]["port"]
    ENV['PGDATABASE'] = arbc[RAILS_ENV]["database"].to_s if arbc[RAILS_ENV]["database"]
    ENV['PGUSER']     = arbc[RAILS_ENV]["username"].to_s if arbc[RAILS_ENV]["username"]
    ENV['PGPASSWORD'] = arbc[RAILS_ENV]["password"].to_s if arbc[RAILS_ENV]["password"]
  end

  desc "Run pqsl and connect to current database"
  task :psql => [:set_pg_env] do
    arbc = ActiveRecord::Base.configurations
    system %{psql \#{arbc[RAILS_ENV]['database']}}
  end

  desc "Dump current database to file"
  task :dump => [:environment,:set_pg_env] do
    arbc = ActiveRecord::Base.configurations
    source_database = arbc[RAILS_ENV]['database']
    pgdump_filename = File.join(RAILS_ROOT,'tmp',"\#{source_database}.pgdump")
    dump_command  = %{pg_dump --format=custom -f \#{pgdump_filename} \#{source_database}}
    puts "Running: \#{dump_command}"
    system dump_command
  end

  def ensure_template_gis_ltree_pg_trgm_intarray_exists
    unless begin
      config = ActiveRecord::Base.configurations[RAILS_ENV]
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres' , 'schema_search_path' => 'public'))
      ActiveRecord::Base.connection.execute("select datname from pg_database where datname = 'template_gis_ltree_pg_trgm_intarray';")[0] 
    rescue 
      false
    end
    then
      abort <<-'EOS'
# The following Ubuntu specific commands are needed to create template_gis_ltree_pg_trgm_intarray
sudo aptitude install postgis postgresql-8.4-postgis
sudo -u postgres psql <<'EOF'
-- Create spatial template database template_gis_ltree_pg_trgm_intarray.
create database template_gis_ltree_pg_trgm_intarray encoding 'utf-8' lc_collate 'nb_NO.UTF-8' lc_ctype 'nb_NO.UTF-8' template = template0;
\c template_gis_ltree_pg_trgm_intarray
create language plpgsql;
\i /usr/share/postgresql/8.4/contrib/postgis.sql
\i /usr/share/postgresql/8.4/contrib/postgis_comments.sql
-- Skip loading of example data
-- \i /usr/share/postgresql-8.4-postgis/spatial_ref_sys.sql
-- Make sure that cloned databases provide access to spatial tables
-- Notice that this is a security risk, and a workaround because
-- postgres does not transfer table ownership on database creation
-- from template
grant all on geometry_columns to public;
grant select on spatial_ref_sys to public;
-- Added non-suggested acl to allow pg_restore of rows.
-- Notice that the user should normally never do inserts into that table.
grant insert on spatial_ref_sys to public;
-- Load ltree
\i /usr/share/postgresql/8.4/contrib/ltree.sql
-- Load pg_trgm
\i /usr/share/postgresql/8.4/contrib/pg_trgm.sql
-- Load _int (intarray)
\i /usr/share/postgresql/8.4/contrib/_int.sql
-- transform new db in template
update pg_database SET datistemplate='true' where datname='template_gis_ltree_pg_trgm_intarray';
EOF
      EOS
    end
  end

  desc "Prepare for restore from database dump"
  # It is not possible to recreate the database from within rake, because
  # rake keeps the database open.
  # Therefore create a file with the needed commands to do the restore.
  task :prepare_restore => [:environment,:set_pg_env] do
    # Ensure that this is never done in the production environment.
    # It does not make sense to copy to and from same destination.
    if RAILS_ENV == 'production' then
      abort "Can not restore into production environment."
    end
    unless ENV['source_rails_env'] then
      abort "Please specify the source_rails_env with:\n \#{$0} source_rails_env=..."
    end
    ensure_template_gis_ltree_pg_trgm_intarray_exists
    arbc = ActiveRecord::Base.configurations
    @source_database = arbc[ENV['source_rails_env']]['database']
    target_database = arbc[RAILS_ENV]['database']
    restore_script_filename = File.join(RAILS_ROOT,'tmp',"pg_restore_\#{@source_database}.sh")
    File.open(restore_script_filename,'w+') do |file|
      file.write <<-EOS
export PGHOST=\#{ENV['PGHOST']}
export PGPORT=\#{ENV['PGPORT']}
export PGUSER=\#{ENV['PGUSER']}
export PGPASSWORD=\#{ENV['PGPASSWORD']}
set -e -x
( dropdb \#{target_database} || true )
createdb --lc-collate 'nb_NO.UTF-8' --lc-ctype 'nb_NO.UTF-8' --encoding 'utf-8' \#{target_database} --template template_gis_ltree_pg_trgm_intarray &&
pg_restore --list \#{RAILS_ROOT}/tmp/\#{@source_database}.pgdump > \#{RAILS_ROOT}/tmp/\#{@source_database}.pglist_with_postgis_ltree_pg_trgm_intarray
\#{RAILS_ROOT}/script/pg_restore_gis_ltree_pg_trgm_intarray_cleanup.rb < \#{RAILS_ROOT}/tmp/\#{@source_database}.pglist_with_postgis_ltree_pg_trgm_intarray > \#{RAILS_ROOT}/tmp/\#{@source_database}.pglist_without_postgis_ltree_pg_trgm_intarray
pg_restore --use-list \#{RAILS_ROOT}/tmp/\#{@source_database}.pglist_without_postgis_ltree_pg_trgm_intarray --single-transaction --no-acl --no-owner -d \#{target_database} \#{RAILS_ROOT}/tmp/\#{@source_database}.pgdump
      EOS
    end
  end

  desc "Restore the current database from specified dump found locally in tmp."
  task :restore => [:prepare_restore] do
    unless @source_database then abort "Missing instance variable @source_database" end
    restore_script_filename = File.join(RAILS_ROOT,'tmp',"pg_restore_\#{@source_database}.sh")
    puts %{Running \#{restore_script_filename}}
    exec("sh", restore_script_filename)
  end

  desc "Restore current database and get a fresh copy from production."
  task :dump_and_restore => [:dump, :restore] do
  end

  desc "Migrate the database and dump the new database structure"
  task :migrate_and_dump_structure => [:migrate, "db:structure:dump"] do
  end
end
RAKEFILE

rakefile 'test.rake', <<-RAKEFILE
namespace :test do
  task :syntax do
    command = "git ls-files --full-name | grep -ie '\\.rb$' | grep -ve '^vendor' | xargs -n 1 ruby -c >/dev/null"
    puts "Executing \#{command}"
    system command
  end
end
RAKEFILE

git :add => 'lib/tasks'
git :commit => "-m 'Added rake tasks'"
