
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "paperclip-vips/version"

Gem::Specification.new do |spec|
  spec.name          = "kt-paperclip-vips"
  spec.version       = PaperclipVips::VERSION
  spec.authors       = ["Ken Greeff", "Mikael Henriksson"]
  spec.email         = ["ken@kengreeff.com", "mikael@mhenrixon.com"]

  spec.summary       = %q{Uses Ruby Vips to when creating thumbnails for faster generation.}
  spec.homepage      = "https://github.com/realhub/paperclip-vips"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|Gemfile|mise.toml/bin)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'kt-paperclip', ">= 5.0.0"
  spec.add_runtime_dependency "ruby-vips", ">= 2.1"
end
