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
    if existing = Dir.entries(templates_path).select{|n| n.match(/^[0-9]+_#{slug}\.rb$/)}.first
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

command :upgrade do |command|
  command.syntax = 'upgrade'
  command.description = "Run pending autobahn upgrade templates"
  command.option '-a', '--all', "Run uncommitted autobahn templates"
  command.option '--no-merge', "Don't merge the upgrade commits from the autobahn to master"
  command.action do |args, options|
    if not File.exists? "vendor/rails"
      STDERR.puts "Autobahn upgrade must be run from the top of your project directory"
      exit 1
    elsif system('git', 'status')
      # TODO: Hide output from git st
      STDERR.puts "There are uncommitted changes. Commit your changes before upgrading."
      exit 1
    elsif not %x{git branch}.match(/^\* master/m)
      STDERR.puts "The master branch must be checked out."
      exit 1
    elsif %x{git branch}.match(/^. autobahn/m)
      STDERR.puts "There already exists an autobahn branch. Dispose of it before upgrading."
      exit 1
    end

    templates_path = File.join(autobahn_repo, 'templates')
    applied = []
    if File.exists?('.autobahn/revision')
      revision = File.read('.autobahn/revision').chomp
      Dir.chdir(autobahn_repo) do
        applied += %{git ls-tree --name-only #{revision} #{templates_path}}.split("\n")
      end
    end

    revision = Dir.chdir(autobahn_repo){%x{git rev-parse HEAD}}.chomp
    if options.all
      pending = Dir.entries(templates_path).reject{|n| n.match(/^\.\.?$/)} - applied
    else
      pending = Dir.chdir(autobahn_repo){%{git ls-tree --name-only #{revision} #{templates_path}}.split("\n")} - applied
    end

    if pending.any?
      system('git', 'checkout', '-b', 'autobahn')
      pending.sort.each do |template|
        template = File.join(templates_path, template)
        puts "Applying upgrade template #{template}"
      end
      FileUtils.makedirs('.autobahn')
      File.open('.autobahn/revision', 'w') do |file|
        file.puts revision
      end
      system 'git', 'add', '.autobahn/revision'
      autobahn_tag = Dir.chdir(autobahn_repo){%x{git name-rev --name-only --no-undefined --tags --always #{revision}}}
      message = "Upgraded to autobahn #{autobahn_tag}"
      system 'git', 'commit', '-m', message
      puts message
      if options.merge
        system('git', 'checkout', 'master')
        system('git', 'merge', '--ff', 'autobahn')
        system('git', 'branch', '-d', 'autobahn')
      else
        puts "Leaving upgrade commits in the autobahn branch."
      end
    else
      puts "All autobahn templates have been applied."
      unless options.all
        puts "Use the --all flag if you want to apply uncommitted templates."
      end
    end
  end
end
