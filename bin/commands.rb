require 'rubygems'
require 'commander/import'
require File.join(File.dirname(__FILE__), '..', 'lib', 'capture')

autobahn_repo = File.expand_path(File.join(File.dirname(__FILE__), '..'))

program :name, 'autobahn'
program :version, Dir.chdir(autobahn_repo){capture("git describe --tag")}.chomp.sub(/^v/, '')
program :description, 'Enterprise Ruby on Rails'

def run(*args)
  system(*args)
  if $?.exitstatus != 0
    raise "Child process exited with status #{$?.exitstatus}"
  end
end

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
  command.option '-u', '--uncommitted', "Run uncommitted autobahn templates"
  command.option '-M', '--no-merge', "Don't merge from  the temporary upgrade branch, but leave it checked out"
  command.option '--branch BRANCH', 'Run the upgrade in the given branch. Defaults to "autobahn"'
  command.option '-f', '--force', "Run the upgrade even if the upgrade branch already exists"
  command.action do |args, options|
    initialized =  Dir.entries('.').length != 2
    options.default :force => false, :branch => "autobahn", :uncommitted => false
    options.default :merge => (not initialized or not capture("git branch").match(/^. #{options.branch}/m))
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
    pending = Dir.chdir(autobahn_repo){capture("git ls-tree --name-only -r #{revision} #{templates_path}").split("\n")}.map{|p| File.basename(p)} - applied
    pending.reject!{|n| !n.match(/\.rb$/)}
    uncommitted = Dir.entries(templates_path).reject{|n| n.match(/^\.\.?$/) || !n.match(/\.rb$/)} - applied - pending
    if options.uncommitted
      if pending.any?
        STDERR.puts "There are committed upgrades that must be applied before the uncommitted ones. Run once without the --uncommitted flag first."
        exit 1
      end
      pending = uncommitted
    end

    if pending.any?
      if initialized
        merge_branch = capture("git branch").match(/^\* ([^ \n]+)/m).captures.first
        if not capture("git branch").match(/^\* #{options.branch}/m) # The upgrade branch is not currently checked out
          if capture("git branch").match(/^  #{options.branch}/m) # The upgrade branch exists
            if options.force
              run('git', 'checkout', options.branch)
            else
              STDERR.puts "The branch #{options.branch.inspect} already exists. Use --force to upgrade in it anyway"
              exit 1
            end
          else # The upgrade branch does not exist
            run('git', 'checkout', '-b', options.branch)
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
          # Use a double proc to work around namespace-conflicts
          _run = Proc.new{|*args| run(*args)}
          Rails::TemplateRunner.send(:define_method, :run) do |*args|
            log_action = if [true, false].member? args.last then args.pop else true end
            log 'executing',  "#{args.join(' ')} from #{Dir.pwd}" if log_action
            _run.call(*args)
          end

          eval "Rails::TemplateRunner.send(:define_method, :autobahn_repo){#{autobahn_repo.inspect}}"

          Rails::TemplateRunner.class_eval do
            def skel(*paths)
              # Copy files from the skel-directory and add them to git
              added = []
              while path = paths.shift
                skel_path = File.join(autobahn_repo, 'skel', path)
                if File.directory? skel_path
                  Dir.entries(skel_path).reject{|p| p.match(/^\.\.?$/)}.each do |p|
                    paths.unshift File.join(path, p)
                  end
                else
                  file path, File.read(skel_path)
                  added << path
                end
              end
              run 'git', 'add', *added if added.any?
            end
          end
        end
        if defined? Rails
          Rails::TemplateRunner.new(template)
        else
          puts "Applying upgrade template #{template}"
          eval(open(template).read, nil, template)
        end
        Dir.chdir project_dir # in case the template changed the current directory
      end
      if !options.uncommitted
        FileUtils.makedirs('.autobahn')
        File.open('.autobahn/revision', 'w') do |file|
          file.puts revision
        end
        run 'git', 'add', '.autobahn/revision'
        autobahn_tag = Dir.chdir(autobahn_repo){capture("git describe --tags #{revision}")}
        message = "Upgraded to autobahn #{autobahn_tag}"
        run 'git', 'commit', '-m', message
        puts message
      end
      if !initialized
        # We're already on the master branch. No need to merge or switch branches
      elsif options.merge and options.branch != merge_branch
        run('git', 'checkout', merge_branch)
        run('git', 'merge', '--ff', '-q', options.branch)
        run('git', 'branch', '-d', options.branch)
      else
        puts "Leaving upgrade commits in the #{options.branch} branch."
      end
    else
      puts "All autobahn templates have been applied."
      if uncommitted.any?
        puts "Use the --uncommitted flag if you want to apply uncommitted templates."
      end
    end
  end
end
