#######################################################################
# syndic8.rb - Ruby interface for Syndic8 (http://syndic8.com/).      #
# by Paul Duncan <pabs@pablotron.org>                                 #
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
#######################################################################

require 'xmlrpc/client'
require 'md5'

#
# Syndic8 - Ruby bindings for the Syndic8 (http://syndic8.com/) XML-RPC
# interface.
#
# Basic Usage:
#   require 'syndic8'
#
#   # simple query
#   s = Syndic8.new
#   feeds = s.find('cooking')
#   feeds.each { |feed| p feed }
#
#   # set number of results and fields returned
#   # (both can affect size and duration of query)
#   s.max_results = 10
#   s.keys -= ['description']
#
#   feeds = s.find('linux')
#   feeds.each { |feed| p feed }
#
# Managing a Subscription List:
#   require 'syndic8'
#   
#   # log in to syndic8 with user "joebob" and password "p455w3rd"
#   s = Syndic8.new('joebob', 'p455w3rd')
#
#   # create a new private list 
#   list_id = s.create_subscription_list("Joebob's Links")
#   
#   # subscribe to pablotron.org on your subscription list
#   s.subscribe_feed(list_id, 'http://pablotron.org/rss/', false)
#
#   # subscribe to NIF Health category on list
#   s.subscribe_category(list_id, 'NIF', 'Health')
#
# Using the Weblog Ping Service:
#   s = Syndic8.new
#   s.ping('Pablotron', 'http://pablotron.org/')
#
class Syndic8
  attr_accessor :keys, :max_results

  VERSION = '0.2.0'

  #
  # Syndic8::Error - Simple wrapper for errors.
  #
  class Error < Exception
    def initialize(*args)
      super(*args)
    end
  end

  # 
  # Create a new Syndic8 object.
  # Note: the username and password are optional, and only used for
  # certain (explicitly labeled) methods.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # connect to syndic8
  #   s = Syndic8.new
  #
  #   # connect to syndic8 with user 'joe' and password 'bob'
  #   s = Syndic8.new('joe', 'bob')
  #
  def initialize(*args)
    @user, @pass = args
    @pass = MD5::new(@pass).to_s if @pass

    # set default options
    @keys = %w{sitename siteurl dataurl description}
    @max_results = -1
    @sort_field = 'sitename'

    # connect to syndic8
    begin
      @rpc = XMLRPC::Client.new('www.syndic8.com', '/xmlrpc.php', 80)
    rescue XMLRPC::FaultException => e
      raise Syndic8::Error, "XML-RPC: #{e.faultCode}: #{e.faultString}"
    end
  end

  #
  # Call an XML-RPC Syndic8 method and return the results, wrapping
  # any exceptions in a Syndic8::Error exception.
  #
  def call(meth, *args)
    begin
      meth_str = (meth =~ /\./) ? meth : 'syndic8.' << meth
      @rpc.call(meth_str, *args)
    rescue XMLRPC::FaultException => e
      raise Syndic8::Error, "XML-RPC: #{e.faultCode}: #{e.faultString}"
    rescue Exception
      raise Syndic8::Error, "Error: #$!"
    end
  end
  private :call

  #
  # Very simple find method, not included in the Syndic8 API.
  # Roughly equivalent to calling Syndic8#find_feeds, and passing the
  # result to Syndic8#get_feed_info.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # return first Syndic8#max_results feeds on cooking
  #   feeds_ary = s.find('cooking')
  #
  def find(str)
    feeds = call('FindFeeds', str, 'sitename', @max_results)
    (feeds && feeds.size > 0) ? call('GetFeedInfo', feeds, @keys) : []
  end

  #
  # Returna list of feeds IDs matching a given search string, sorting
  # by +sort_field+.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   ids = s.find_feeds 'poop'
  #
  def find_feeds(str, sort_field = @sort_field, max_results = @max_results)
    call('FindFeeds', str, sort_field, max_results)
  end


  #
  # Matches the given pattern against against the SiteURL field of every
  # feed, and returns the IDs of matching feeds.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   ids = s.find_sites 'reader.com' 
  #
  def find_sites(str)
    call('FindSites', str)
  end

  # 
  # Matches the given pattern against all text fields of the user list,
  # and returns user IDs of matching users.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   user_ids = s.find_users 'pabs' 
  #
  def find_users(str)
    call('FindUsers', str)
  end

  #
  # Returns an array of the supported category schemes.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   schemes = s.category_schemes
  #
  def category_schemes
    call('GetCategorySchemes')
  end

  #
  # Returns the top-level category names for the given scheme.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   roots = s.category_roots
  #
  def category_roots(str)
    call('GetCategoryRoots', str)
  end


  #
  # Returns the set of known categories for the given category scheme.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   trees = s.category_trees
  #
  def category_tree(str)
    call('GetCategoryTree', str)
  end

  #
  # Returns the immediate child categories of the given category.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   kids = s.category_children(scheme, category)
  #
  def category_children(scheme, category)
    call('GetCategoryChildren', scheme, category)
  end

  #
  # Accepts a start date, and optionally an end date, an array of fields
  # to check, and a list of fields to return. It checks the change log for
  # the feeds, and returns the requested feed fields for each feed where
  # a requested field has changed.
  #
  # If end_date is unspecified or nil, it defaults to today.  
  # check_fields is nil or unspecified, it defaults to all fields.  If
  # ret_fields is nil or unspecified it defaults to @keys.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # return a list of feeds that have changed since December 1st, 
  #   # 2003
  #   changed_ary = s.changed_feeds(Time::mktime(2003, 12, 1))
  #
  #   # Return a list of URLs of feeds that have changed descriptions
  #   # since the beginning of the month
  #   t = Time.now
  #   changed = s.changed_feeds(Time::mktime(t.year, t.month), Time::now, 
  #                             ['description'], ['siteurl'])
  #
  def changed_feeds(start_date, end_date = nil, check_fields = nil, ret_fields = nil)
    start_str = start_date.strftime('%Y-%m-%d')
    end_str = (end_date || Time.now).strftime('%Y-%m-%d')
    check_fields ||= fields
    ret_fields ||= @keys

    call('GetChangedFeeds', check_fields, start_str, end_str, ret_fields)
  end

  #
  # Returns the number of feeds that are in the Syndic8 feed table.
  #
  # Raises Syndic8::Error on error.
  #
  # Aliases: 
  #   Syndic8#size
  #
  # Example:
  #   num_feeds = s.size
  #
  def feed_count
    call('GetFeedCount').to_i
  end

  alias :size :feed_count

  #
  # Get a list of fields returned by Syndic8.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   fields = s.fields
  #
  def fields
    call 'GetFeedFields'
  end


  #
  # Returns an array of arrays containing the requested fields for each
  # feed ID. Field names and interpretations are subject to change.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # get info for given feed IDs
  #   info_ary = feed_info(ids)
  #
  def feed_info(feed_ids, fields = @keys)
    call('GetFeedInfo', feed_ids, fields)
  end

  #
  # Returns an array of feeds IDs in the given category within the given
  # scheme.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # get a list of feeds IDs in the NIF Health category
  #   ids = s.feeds_in_category('NIF', 'Health')
  #
  def feeds_in_category(scheme, category)
    call('GetFeedsInCategory', scheme, category)
  end
  
  #
  # Returns a hash of valid feed states and descriptions.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   feed_states = s.states
  #
  def states
    call('GetFeedStates').inject({}) { |ret, h| ret[h['state']] = h['name'] }
  end

  #
  # Returns the highest assigned feed ID.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   last_id = s.last_feed
  #
  def last_feed
    call('GetLastFeed')
  end

  #
  # Returns an array of hashes. Each structure represents a single type
  # of feed license.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   licenses = s.licenses
  # 
  def licenses
    call('GetLicenses')
  end

  #
  # Returns an array of the supported location schemes.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   loc_schemes = s.location_schemes
  #
  def location_schemes
    call('GetLocationSchemes')
  end

  #
  # Returns a hash of of toolkits known to Syndic8.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   toolkits = s.toolkits
  #
  def toolkits
    call('GetToolkits').inject({}) { |ret, h| ret[h['id']] = ret['name'] }
  end

  #
  # Accepts the UserID of a known Syndic8 user and returns a structure
  # containing all of the information from the users table. Field names
  # and interpretations are subject to change.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   info = s.user_info('pabs')
  #
  def user_info(user)
    call('GetUserInfo', user)
  end

  #
  # Takes the given feed field, relationship (<, >, <=. >=, !=, =, like,
  # or regexp), and feed value and returns the list of feeds with a
  # matching value in the field.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   feed_ids = s.query_feeds('description', 'regexp', 'poop')
  #
  def query_feeds(match_field, operator, value, sort_field)
    call('QueryFeeds', match_field, operator, value, sort_field)
  end

  #
  # Sets the feed's category within the given scheme.
  #
  # Note: You must be logged in to use this method, and your account
  # must have the Categorizer role.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.set_feed_category(id, 'Syndic8', 'Culture')
  #
  def set_feed_category(feed_id, cat_scheme, cat_value)
    call('SetFeedCategory', @user, @pass, feed_id, cat_scheme, cat_value)
  end

  #
  # Sets the feed's location within the given location scheme.
  #
  # Note: You must be logged in to use this method, and your account
  # must have the Categorizer role.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.set_feed_location(id, 'Geo-IP', 'asdF')
  #
  def set_feed_location(feed_id, loc_scheme, loc_value)
    call('SetFeedLocation', @user, @pass, feed_id, loc_scheme, loc_value)
  end

  #
  # Sets a user's location to the given value.
  #
  # Note: You must be logged in to use this method, and your account
  # must have the Editor role.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.set_user_location(user_id, 'Kentucky, USA')
  #   
  #
  def set_user_location(user_id, location)
    call('SetUserLocation', @user, @pass, user_id, location)
  end

  #
  # Checks to see if data_url is that of a known feed. If it is not, the
  # feed is entered as a new feed. In either case, a feed ID is returned.
  #
  # Note: You must be logged in to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.suggest_data_url('http://pablotron.org/rss/')
  # 
  def suggest_data_url(data_url)
    call('SuggestDataURL', data_url, @user)
  end

  #
  # Checks to see if site_url is that of a known feed. If it is not, the
  # feed is entered as a new feed. In either case, a feed ID is returned.
  #
  # Note: You must be logged in to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.suggest_site_url('http://pablotron.org/')
  #
  def suggest_site_url(site_url)
    call('SuggestSiteURL', site_url, @user)
  end

  #
  # Sends notification of a change at the given site.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.ping('Pablotron', 'http://pablotron.org/')
  #
  def ping(site_name, site_url)
    call('weblogUpdates.Ping', site_name, site_url)
  end

  #
  # Sends notification of a change at the given site.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.ping('Pablotron', 'http://pablotron.org/', 0, 'http://pablotron.org/rss/')
  #
  def extended_ping(site_name, site_url, unknown, data_url)
    call('weblogUpdates.ExtendedPing', site_name, site_url, unknown, data_url)
  end

  #
  # Creates a new subscription list for the given user, and returns the
  # List identifier of the list.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Examples:
  #   # create a new private list called 'foo-private'
  #   id = s.create_subscription_list('foo-private')
  #
  #   # create a new public list called 'Cool_Sites'
  #   id = s.create_subscription_list('Cool_Sites', true)
  #
  def create_subscription_list(list_name, public = false)
    call('CreateSubscriptionList', @user, @pass, list_name, public).to_i
  end

  #
  # Creates a new subscription list for the given user. The list will
  # contain feeds referenced from the given HTML page. If AutoSuggest is
  # given, unknown feeds will be automatically suggested as new feeds.
  #
  # Returns an array of hashes with ID, feed ID, and status code.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   ary = s.create_subscription_list_from_html('pablotron_feeds', true, 'http://pablotron.org/', true)
  #
  def create_subscription_list_from_html(list_name, public, html_url, auto_suggest)
    call('CreateSubscriptionListFromHTML', @user, @pass, list_name, public, html_url, auto_suggest)
  end
  
  #
  # Creates a new subscription list for the given user. The list will
  # contain the feeds from the given OPML. If AutoSuggest is given,
  # unknown feeds will be automatically suggested as new feeds.
  # 
  # Returns an array of hashes, each with ID (from OPML), feed ID, and
  # status code.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   ary = s.create_subscription_list_from_opml('raggle feeds', true, 'http://pablotron.org/download/feeds.opml', true)
  #
  def create_subscription_list_from_opml(list_name, public, opml_url, auto_suggest)
    call('CreateSubscriptionListFromOPML', @user, @pass, list_name, public, opml_url, auto_suggest)
  end

  #
  # Ceates a new Syndic8 user.  Returns true on success or false on
  # failure.
  #
  # Note: You must be logged in and have the CreateUser option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   success = s.create_user('mini-pabs', 'Mini', 'Pabs', 'minipabs@pablotron.org', '', 'PersonalList', true, 'http://mini.pablotron.org/', '', '')
  #
  def create_user(user_id, first_name, last_name, email, pass, roles, options, email_site_info, home_page, style_sheet, vcard)
    call('CreateUser', @user, @pass, user_id, first_name, last_name, email, pass, roles, options, email_site_info, home_page, style_sheet, vcard).to_i == 1
  end

  # 
  # Deletes the indicated subscription list. All feeds and categories
  # will be removed from the list.  Returns true on success or false on
  # failure.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # create and then immediately delete list
  #   id = s.create_subscription_list('Cool_Sites', true)
  #   s.delete_subscription_list(id)
  #
  def delete_subscription_list(list_id)
    call('DeleteSubscriptionList', @user, @pass, list_id).to_i == 1
  end

  # 
  # Returns the set of feeds that the user is subscribed to both
  # directly (as feeds) and indirectly (via a category of feeds).
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   feeds = s.subscribed(list_id)
  #
  def subscribed(list_id, field_names = nil)
    call('GetSubscribed', @user, @pass, list_id, field_names)
  end

  #
  # Returns the set of categories that the user is subscribed to, as an
  # array of hashes containing schemes and categories.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   cats = s.subscribed_categories(list_id)
  #
  def subscribed_categories(list_id)
    call('GetSubscribedCategories', @user, @pass, list_id)
  end

  #
  # Returns the list of subscription lists for the given user. Each
  # hash includes the list id, name, and status (public or
  # private).
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   listss = s.subscribion_lists(list_id)
  #
  def subscription_lists
    call('GetSubscriptionLists', @user, @pass)
  end

  #
  # Changes values stored for a list. The new_values hash argument must
  # contain new values for the items (name, public, etc.)
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # create a list 'Cool_Sites', then rename it to 'Dumb_Sites'
  #   id = s.create_subscription_list('Cool_Sites', true)
  #   s.set_subscription_list_info(id, {'name' => 'Dumb_Sites'}
  #   
  def set_subscription_list_info(list_id, new_values)
    call('SetSubscriptionListInfo', @user, @pass, list_id, new_values)
  end

  #
  # Subscribes the user's given list (0 is the public list) to the given
  # category of feeds.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # create a new Gadgets list and subscribe to the
  #   # NIF PDA list
  #   list_id = s.create_subscription_list('Gadgets', true)
  #   s.subscribe_category(list_id, 'NIF', 'PDA')
  #
  def subscribe_category(list_id, cat_scheme, cat)
    call('SubscribeCategory', @user, @pass, cat_scheme, cat, list_id)
  end

  #
  # Subscribes the user's given list (0 is the public list) to the given
  # feed. The user must have the PersonalList option. If a DataURL is
  # given and AutoSuggest is true and the feed is not known, it will be
  # suggested as if by entered by user ID.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   # subscribe to pablotron.org on the public list, and suggest it if
  #   # Syndic8 doesn't already know about it
  #   s.subscribe_feed(0, 'http://pablotron.org/rss/', true)
  #
  def subscribe_feed(list_id, feed_id, auto_suggest)
    call('SubscribeFeed', @user, @pass, feed_id, list_id, auto_suggest)
  end

  #
  # Unsubscribes the user from the given category of feeds within the
  # list.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.unsubscribe_category(0, 'NIF', 'Health')
  #
  def unsubscribe_category(list_id, cat_scheme, cat)
    call('UnSubscribeCategory', @user, @pass, cat_scheme, cat, list_id)
  end

  # Unsubscribes the user from the given feed within the list.
  #
  # Note: You must be logged in and using the PersonalList option in
  # order to use this method.
  #
  # Raises Syndic8::Error on error.
  #
  # Example:
  #   s.unsubscribe_feed(0, feed_id)
  #
  def unsubscribe_feed(list_id, feed_id)
    call('UnSubscribeFeed', @user, @pass, feed_id, list_id)
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

  # This test code is slightly dated, but still works correctly.  at
  # some point I should make it a bit more comprehensive :D
  begin
    s = Syndic8.new
    s.keys -= ['description', 'siteurl']

    feeds = s.find(search_str)
    feeds.each do |feed|
      puts '"' + s.keys.map { |key| feed[key].escape }.join('","') + '"'
    end
  rescue Syndic8::Error => e
    puts 'Error:' +  e.to_s
  end
end
