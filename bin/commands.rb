require 'rubygems'
require 'commander/import'
require File.join(File.dirname(__FILE__), '..', 'lib', 'capture')

autobahn_repo = File.expand_path(File.join(File.dirname(__FILE__), '..'))

program :name, 'autobahn'
program :version, Dir.chdir(autobahn_repo){capture("git describe --tag")}.chomp.sub(/^v/, '')
program :description, 'Enterprise Ruby on Rails'

command :init do |command|
  command.syntax = "init [options] <directory>"
  command.description = "Initialize an autobahn project"
  command.option '--rails-revision REVISION', String, 'The rails revision to checkout'
  command.action do |args, options|
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
    command(:upgrade).run
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
    puts
    puts File.read(File.join(templates_path, 'README'))
    puts
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
    initialized =  Dir.entries('.').length != 2
    options.default :force => false, :branch => "autobahn"
    options.default :merge => (not initialized or capture("git branch").match(/^. #{options.branch}/m))
    if initialized and not File.exists? "vendor/rails"
      STDERR.puts "Autobahn upgrade must be run from the top of your project directory"
      exit 1
    elsif initialized and ((capture('git', 'status') and true) rescue false)
      # git status exists with a nonzero status if there is nothing to commit
      STDERR.puts "There are uncommitted changes. Commit your changes before upgrading."
      exit 1
    end

    templates_path = File.join(autobahn_repo, 'templates')
    applied = []
    if File.exists?('.autobahn/revision')
      revision = File.read('.autobahn/revision').chomp
      Dir.chdir(autobahn_repo) do
        applied += capture("git ls-tree --name-only -r #{revision} #{templates_path}").split("\n").map{|p| File.basename(p)}
      end
    end

    revision = Dir.chdir(autobahn_repo){capture("git rev-parse HEAD")}.chomp
    if options.all
      pending = Dir.entries(templates_path).reject{|n| n.match(/^\.\.?$/)} - applied
    else
      pending = Dir.chdir(autobahn_repo){capture("git ls-tree --name-only -r #{revision} #{templates_path}").split("\n")}.map{|p| File.basename(p)} - applied
    end
    pending.reject!{|n| !n.match(/\.rb$/)}

    if pending.any?
      if initialized
        merge_branch = capture("git branch").match(/^\* ([^ \n]+)/m).captures.first
        if not capture("git branch").match(/^\* #{options.branch}/m) # The upgrade branch is not currently checked out
          if capture("git branch").match(/^  #{options.branch}/m) # The upgrade branch exists
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
      else
        merge_branch = "master"
      end

      project_dir = Dir.pwd
      pending.sort.each do |template|
        template = File.join(templates_path, template)
        if not defined? Rails and File.exists?('vendor/rails')
          # Configure rails
          require './vendor/rails/railties/lib/rails_generator/generators/applications/app/template_runner'
        end
        if defined? Rails
          Rails::TemplateRunner.new(template)
        else
          puts "Applying upgrade template #{template}"
          eval(open(template).read, nil, template)
        end
        Dir.chdir project_dir # in case the template changed the current directory
      end
      FileUtils.makedirs('.autobahn')
      File.open('.autobahn/revision', 'w') do |file|
        file.puts revision
      end
      system 'git', 'add', '.autobahn/revision'
      autobahn_tag = Dir.chdir(autobahn_repo){capture("git describe --tags #{revision}")}
      message = "Upgraded to autobahn #{autobahn_tag}"
      system 'git', 'commit', '-m', message
      puts message
      if !initialized
        # We're already on the master branch. No need to merge or switch branches
      elsif options.merge and options.branch != merge_branch
        system('git', 'checkout', merge_branch)
        system('git', 'merge', '--ff', '-q', options.branch)
        system('git', 'branch', '-d', options.branch)
      else
        puts "Leaving upgrade commits in the #{options.branch} branch."
      end
    else
      puts "All autobahn templates have been applied."
      unless (options.all or initialized)
        puts "Use the --all flag if you want to apply uncommitted templates."
      end
    end
  end
end
