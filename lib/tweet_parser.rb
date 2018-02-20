# Tweet Parser used by twitter-list-watcher
# Parses tweets and evaluates whether they match various configurations
require 'rambling-trie'
require './lib/tweet_formatter'

class TweetParser
  attr_reader :tweet_content
  # Create a new filter object
  def initialize(config_array)
    # We're using Tries here because they're much quicker for Ruby to search through
    # O = log(n) for Trie#include?, as opposed to O = n^2 for Array#includes?
    @blacklist_config   = convert_to_tries(config_array[:blacklist])
    @normal_config      = convert_to_tries(config_array[:normal])
    @priority_config    = convert_to_tries(config_array[:priority])
    @formatter          = TweetFormatter.new
    @tweet_content = Hash.new
  end

  # Parse a single tweet and check if it contains what we're looking for
  def parse(tweet)
    # Get tweet content
    @tweet_content = { 'uris' => @formatter.get_uri_hosts(tweet),
                      'hashtags' => @formatter.get_hashtags(tweet),
                      'mentions'=> @formatter.get_mentions(tweet),
                      'text' => @formatter.get_text(tweet) }

    # Add to the appropriate queue if it contains content we're looking for
    if !compare(@blacklist_config, @tweet_content)
      if compare(@priority_config, @tweet_content) # tweet matches config[priority]
        return 2
      elsif compare(@normal_config, @tweet_content)# tweet matches config[normal]
        return 1
      else # tweet does not match any config, or our blacklist
        return 0
      end
    else # tweet matches blacklist; other matches ignored
      return -1
    end

  end

  # Reload configuration options
  # todo: define this
  def reload(config)
    # ...
  end

  private

  # Take a configuration array and replace each value with tries (via array_to_trie)
  # If a key has no values, add 'nil' to our hash
  def convert_to_tries(config_hash)
    conf = Hash.new
    config_hash.each do |key, value|
      if /text/.match(key)
        conf.store(key, value)
      else
        conf.store(key, !value.nil? ? array_to_trie(value) : nil)
      end
    end
  end

  # Take an input array and convert it to a trie
  def array_to_trie(array)
    trie = Rambling::Trie.create
    array.each { |item| trie << item }
  end

  # Check if a given array contains a term of interest (contained in a trie)
  def contains?(trie, array)
    if !(array.nil? || trie.nil?)
      array.each { |item| return true if trie.include? item }
    end
    false
  end

  # Use regex to determine if a given array contains a term of interest
  def matches?(config_array, content_string)
    config_array.each { |key| return true if /#{key}/.match(content_string) } unless config_array.nil?
    false
  end

  # Compare an configuration array (e.g.: blacklisted tries) to a content array (i.e.: tweet contents)
  def compare(config, content)
    return true if contains?(config['uris'],content['uris']) ||
        contains?(config['hashtags'],content['hashtags']) ||
        contains?(config['mentions'],content['mentions']) ||
        matches?(config['text'], content['text'])
    false
  end
end