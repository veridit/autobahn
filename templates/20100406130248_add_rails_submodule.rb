# Add rails submodule
unless File.exists?('vendor/rails')
  capture 'git', 'submodule', 'add', 'git://github.com/rails/rails.git', 'vendor/rails'
  Dir.chdir 'vendor/rails' do
    capture 'git', 'checkout', "v2.3.5"
  end
  capture 'git', 'add', 'vendor/rails'
  capture 'git', 'commit', '-m', "Added rails v2.3.5"
end
