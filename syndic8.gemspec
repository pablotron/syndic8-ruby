require 'rubygems'

spec = Gem::Specification.new do |s|

  #### Basic information.

  s.name = 'Syndic8-Ruby'
  s.version = '0.2.0'
  s.summary = <<-EOF
    Syndic8 (http://www.syndic8.com/) bindings for Ruby.
  EOF
  s.description = <<-EOF
    Delicious (http://www.syndic8.com/) bindings for Ruby.
  EOF

  s.requirements << 'Ruby, version 1.8.0 (or newer)'
  s.requirements << 'xmlrpc4r (included with Ruby 1.8)'

  #### Which files are to be included in this gem?  Everything!  (Except CVS directories.)

  s.files = Dir.glob("**/*").delete_if { |item| item.include?("CVS") }

  #### C code extensions.

  s.require_path = '.' # is this correct?
  # s.extensions << "extconf.rb"

  #### Load-time details: library and application (you will need one or both).
  s.autorequire = 'syndic8'
  s.has_rdoc = true
  s.rdoc_options = ['--webcvs',
  'http://cvs.pablotron.org/cgi-bin/viewcvs.cgi/syndic8-ruby/', '--title',
  'Syndic8-Ruby API Documentation', 'syndic8.rb', 'README', 'ChangeLog',
  'COPYING', 'TODO']

  #### Author and project details.

  s.author = 'Paul Duncan'
  s.email = 'pabs@pablotron.org'
  s.homepage = 'http://www.pablotron.org/software/syndic8-ruby/'
  s.rubyforge_project = 'syndic8-ruby'
end
