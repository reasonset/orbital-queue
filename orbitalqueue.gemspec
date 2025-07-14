Gem::Specification.new do |s|
  s.required_ruby_version = ">= 2.6"
  s.name        = 'orbitalqueue'
  s.version     = '0.0.1'
  s.summary     = 'Orbital Queue'
  s.description = 'File-based queue library for orbital design pattern.'
  s.authors     = ["Masaki Haruka"]
  s.email       = ["yek@reasonset.net"]
  
  s.files       = Dir["lib/*.rb"] + ["README.md", "LICENSE"]
  s.homepage    = "https://github.com/reasonset/orbital-queue"
  s.license     = 'Apache-2.0'
end
