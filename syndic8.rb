#######################################################################
# syndic8.rb - Ruby interface for Syndic8.com.                        #
# by Paul Duncan <pabs@pablotron.org>                                 #
#                                                                     #
#                                                                     #
# Copyright (C) 2004 Paul Duncan                                      #
#                                                                     #
# Permission is hereby granted, free of charge, to any person         #
# obtaining a copy of this software and associated documentation      #
# files (the "Software"), to deal in the Software without             #
# restriction, including without limitation the rights to use, copy,  #
# modify, merge, publish, distribute, sublicense, and/or sell copies  #
# of the Software, and to permit persons to whom the Software is      #
# furnished to do so, subject to the following conditions:            #
#                                                                     #
# The above copyright notice and this permission notice shall be      #
# included in all copies of the Software, its documentation and       #
# marketing & publicity materials, and acknowledgment shall be given  #
# in the documentation, materials and software packages that this     #
# Software was used.                                                  #
#                                                                     #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,     #
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF  #
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND               #
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY    #
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF          #
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION  #
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.     #
#                                                                     #
#                                                                     #
# Usage:                                                              #
#   require 'syndic8'                                                 #
#                                                                     #
#   # simple query                                                    #
#   s = Syndic8.new                                                   #
#   ary = s.find('cooking')                                           #
#   ary.each { |feed| p feed }                                        #
#                                                                     #
#   # set number of results and fields returned                       #
#   # (both can affect size and duration of query)                    #
#   s.max_results = 10                                                #
#   s.keys -= 'description'                                           #
#                                                                     #
#   ary = s.find('linux')                                             #
#   ary.each { |feed| p feed }                                        #
#                                                                     #
#######################################################################

require 'xmlrpc/client'

class Syndic8
  attr_accessor :keys, :max_results
  VERSION = '0.1.0'

  def initialize
    @keys = %w{sitename siteurl dataurl description}
    @max_results = -1
    @rpc = XMLRPC::Client.new('www.syndic8.com', '/xmlrpc.php', 80)
  end

  def call(meth, *args)
    @rpc.call("syndic8.#{meth}", *args)
  end
  private :call

  #
  # find feeds matching a given search string
  #
  def find(str)
    begin
      feeds = call('FindFeeds', str, 'sitename', @max_results)
      (feeds && feeds.size > 0) ? call('GetFeedInfo', feeds, @keys) : []
    rescue XMLRPC::FaultException => e
      raise "Syndic8 Error #{e.faultCode}: #{e.faultString}"
    end
  end

  #
  # get a list of fields returned by Syndic8
  #
  def fields
    call 'GetFeedFields'
  end
end

#############
# test code #
#############
if __FILE__ == $0
  class String
    def escape
      gsub(/"/, '\\"')
    end
  end

  search_str = ARGV.join(' ') || 'cooking'

  begin
    s = Syndic8.new
    feeds = s.find(search_str)
    feeds.each do |feed|
      puts '"' + s.keys.map { |key| feed[key].escape }.join('","') + '"'
    end
  rescue XMLRPC::FaultException => e
    puts 'Error:' +  e.faultCode + e.faultString
  end
end
