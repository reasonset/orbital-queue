Gem::Specification.new do |s|
  s.required_ruby_version = ">= 2.6"
  s.name        = 'orbitalqueue'
  s.version     = '0.0.3'
  s.summary     = 'File-based queue system for Orbital Design Pattern'
  s.description = 'OrbitalQueue is a lightweight Ruby library that implements the Orbital Design Pattern via a file-based queuing mechanism. Ideal for modular systems requiring isolated message handling.'
  s.authors     = ["Masaki Haruka"]
  s.email       = ["yek@reasonset.net"]
  
  s.files       = Dir["lib/**/*.rb"] + ["README.md", "LICENSE"]
  s.homepage    = "https://github.com/reasonset/orbital-queue"
  s.license     = 'Apache-2.0'

  s.metadata = {
    "source_code_uri" => "https://github.com/reasonset/orbital-queue",
    "homepage_uri" => s.homepage,
    "bug_tracker_uri" => "https://github.com/reasonset/orbital-queue/issues"
  }
end
