# Create database configuration file

project = File.basename(Dir.pwd)

unless File.exists? "config/database.yml"
  file "config/database.yml" do
    password = capture('pwgen', '12').chomp
    [:development, :testing, :staging, :demo, :production].map do |stage|
      <<-EOS
#{stage}:
  adapter: postgresql
  encoding: unicode
  database: #{project}_#{stage}
  pool: 5
  username: #{project}
  password: #{password}
  host: localhost
  port: 5432

EOS
    end.join
  end
  git :add => 'config/database.yml'
  git :commit => '-m "Generated database configuration file"'
end
