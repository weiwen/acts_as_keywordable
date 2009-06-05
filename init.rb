# Include hook code here
require 'acts_as_keywordable'
ActiveRecord::Base.send(:include, CC::Acts::Keywordable)

