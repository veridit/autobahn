# Add rails submodule
unless File.exists?('vendor/rails')
  system 'git', 'submodule', 'add', 'git://github.com/rails/rails.git', 'vendor/rails'
  Dir.chdir 'vendor/rails' do
    system 'git', 'checkout', "v2.3.5"
  end
  system 'git', 'add', 'vendor/rails'
  system 'git', 'commit', '-m', "Added rails v2.3.5"
end
