# Add rails submodule
unless File.exists?('vendor/rails')
  run 'git', 'submodule', 'add', 'git://github.com/rails/rails.git', 'vendor/rails'
  Dir.chdir 'vendor/rails' do
    run 'git', 'checkout', "v2.3.5"
  end
  run 'git', 'add', 'vendor/rails'
  run 'git', 'commit', '-m', "Added rails v2.3.5"
end
