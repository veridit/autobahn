Gem::Specification.new do |spec|
  spec.platform    = Gem::Platform::RUBY
  spec.name        = 'autobahn'
  spec.version     = %x{git describe --tag}.chomp.sub(/^v/, '')
  spec.summary     = 'Enterprise Ruby on Rails'

  spec.authors     = ['Matias Hermanrud Fjeld', 'Jørgen Hermanrud Fjeld']
  spec.email       = ['matias@veridit.no', 'Jørgen Hermanrud Fjeld']
  spec.homepage    = 'http://www.github.com/veridit/autobahn'

  spec.executable = 'autobahn'
  spec.add_dependency 'commander', '>= 4.0.2'
end
