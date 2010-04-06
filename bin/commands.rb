require 'rubygems'
require 'commander/import'

program :name, 'autobahn'
program :version, File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).chomp
program :description, 'Enterprise Ruby on Rails'

autobahn_repo = File.expand_path(File.join(File.dirname(__FILE__), '..'))

command :init do |command|
  command.syntax = "init [options] <directory>"
  command.description = "Initialize an autobahn project"
  command.option '--rails-revision REVISION', String, 'The rails revision to checkout'
  command.action do |args, options|
    options.default :rails_revision => 'v3.0.0.beta1'
    if args.empty?
      if File.exists?('vendor/rails') or Dir.entries('.') == ['.', '..']
        project_path = File.expand_path('.')
      else
        puts "Missing project directory"
        exit 1
      end
    else
      project_path = File.expand_path(args.first)
    end

    if File.exists?(File.join(project_path, '.autobahn_revision'))
      puts "#{project_path} has already been initialized."
      exit
    end

    FileUtils.makedirs project_path
    Dir.chdir project_path
    unless File.exists?('.git')
      system 'git', 'init'
      system 'git', 'commit', '--allow-empty', '-m', 'Initial Commit'
    end
    unless File.exists?('vendor/rails')
      system 'git', 'submodule', 'add', 'git://github.com/rails/rails.git', 'vendor/rails'
      Dir.chdir 'vendor/rails'
      system 'git', 'checkout', options.rails_revision
      rails_tag = %x{git describe --tags}
      Dir.chdir project_path
      system 'git', 'add', 'vendor/rails'
      system 'git', 'commit', '-m', "Added rails #{rails_tag}"
    end

    template_path = File.join(File.dirname(__FILE__), '..', 'templates', 'template.rb')

    system 'ruby', File.join(project_path, 'vendor', 'rails', 'railties', 'bin', 'rails'), project_path, "--template=#{template_path}"
    # TODO: Store .autobahn_revision
  end
end

command "generate template" do |command|
  command.syntax = 'generate template <name>'
  command.description = "Generate an autobahn upgrade template"
  command.action do |args, options|
    name = args.first || ask("What should the template be named? ")
    slug = name.downcase.gsub(/[^a-z0-9]+/, '_').split('_').join('_')
    templates_path = File.join(autobahn_repo, 'templates')
    if existing = Dir.entries(templates_path).select{|name| name.match(/^[0-9]+_#{slug}\.rb$/)}.first
      puts "A template with that name already exists: #{File.join(templates_path, existing)}"
    else
      timestamp = DateTime.now.strftime('%Y%m%d%H%M%S')
      path = File.join(templates_path, "#{timestamp}_#{slug}.rb")
      File.open(path, 'w') do |file|
        file.write("# #{name}\n")
      end
      puts "Created #{path}"
    end
  end
end
