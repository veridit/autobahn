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

    if File.exists?(File.join(project_path, '.autobahn/revision'))
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
  command.option '-M', '--no-merge', "Don't merge from  the temporary upgrade branch, but leave it checked out"
  command.option '--branch BRANCH', 'Run the upgrade in the given branch. Defaults to "autobahn"'
  command.option '-f', '--force', "Run the upgrade even if the upgrade branch already exists"
  command.action do |args, options|
    options.default :force => false, :branch => "autobahn"
    options.default :merge => %x{git branch}.match(/^. #{options.branch}/m)
    if not File.exists? "vendor/rails"
      STDERR.puts "Autobahn upgrade must be run from the top of your project directory"
      exit 1
    elsif system('git', 'status')
      # TODO: Hide output from git st
      STDERR.puts "There are uncommitted changes. Commit your changes before upgrading."
      exit 1
    end

    templates_path = File.join(autobahn_repo, 'templates')
    applied = []
    if File.exists?('.autobahn/revision')
      revision = File.read('.autobahn/revision').chomp
      Dir.chdir(autobahn_repo) do
        applied += %x{git ls-tree --name-only #{revision} #{templates_path}}.split("\n")
      end
    end

    revision = Dir.chdir(autobahn_repo){%x{git rev-parse HEAD}}.chomp
    if options.all
      pending = Dir.entries(templates_path).reject{|n| n.match(/^\.\.?$/)} - applied
    else
      pending = Dir.chdir(autobahn_repo){%x{git ls-tree --name-only #{revision} #{templates_path}}.split("\n")} - applied
    end

    if pending.any?
      merge_branch = %x{git branch}.match(/^\* ([^ \n]+)/m).captures.first
      if not %x{git branch}.match(/^\* #{options.branch}/m) # The upgrade branch is not currently checked out
        if %x{git branch}.match(/^  #{options.branch}/m) # The upgrade branch exists
          if options.force
            system('git', 'checkout', options.branch)
          else
            STDERR.puts "The branch #{options.branch.inspect} already exists. Use --force to upgrade in it anyway"
            exit 1
          end
        else # The upgrade branch does not exist
          system('git', 'checkout', '-b', options.branch)
        end
      elsif not options.force
        STDERR.puts "The branch #{options.branch.inspect} exists and is checked out. Use --force to upgrade in it"
        exit 1
      end

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
      if options.merge and options.branch != merge_branch
        system('git', 'checkout', merge_branch)
        system('git', 'merge', '--ff', '-q', options.branch)
        system('git', 'branch', '-d', options.branch)
      else
        puts "Leaving upgrade commits in the #{options.branch} branch."
      end
    else
      puts "All autobahn templates have been applied."
      unless options.all
        puts "Use the --all flag if you want to apply uncommitted templates."
      end
    end
  end
end
