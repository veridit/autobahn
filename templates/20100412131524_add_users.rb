# Create users

skel 'lib/autobahn.rb', 'lib/autobahn/user.rb'

file "app/models/user.rb", <<-EOF
class User < ActiveRecord::Base
  include Autobahn::User
end
EOF

git :add => "app/models/user.rb"

file "db/migrate/#{DateTime.now.strftime('%Y%m%d%H%M%S')}_create_users.rb", <<-EOF
class CreateUsers < ActiveRecord::Migration
  def self.up
    execute %{
      CREATE TABLE users (
        id serial PRIMARY KEY,
        name varchar UNIQUE NOT NULL,
        email varchar UNIQUE NOT NULL,
        password_digest varchar NOT NULL,
        password_salt varchar NOT NULL

        CONSTRAINT "email not blank" CHECK (email != ''),
        CONSTRAINT "name not blank" CHECK (email != ''),
        CONSTRAINT "email must be an email address" CHECK (email ~* '^([^@ ]+)@((?:[-a-z0-9æøå]+\.)+[a-z]{2,})$')
      );
    }
  end

  def self.down
    drop_table :users
  end
end
EOF

git :add => "db/migrate"

git :commit => '-m "Added model User"'
