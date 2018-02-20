# Tweet Formatter for twitter-list-watcher
# Fix Twitter formatting/structure issues & make things a little easier to work with
require 'uri'

class TweetFormatter
  def initialize
  end

  # Return an array of URI hosts
  # We just want the host (string), and not the full Addressable::URI
  def get_uri_hosts(tweet)
    list = []
    #tweet.uris.each { |uri| list << uri.expanded_uri.host.downcase } if tweet.uris?

    # Remove subdomains (e.g.: www.example.org => example.org)
    regex = '[[:word:]]{1,}\.[[:word:]]{1,}\z'
    tweet.uris.each do |uri|
      m = /#{regex}/.match(uri.expanded_uri.host.downcase)
      list << m[0]
    end

    list
  end

  # Return an array of hashtags
  def get_hashtags(tweet)
    list = []
    tweet.hashtags.each { |hashtag| list << hashtag.text.downcase } if tweet.hashtags?
    list
  end

  # Return an array of mentions
  def get_mentions(tweet)
    list = []
    tweet.user_mentions.each { |mention| list << mention.screen_name.downcase } if tweet.user_mentions?
    list
  end

  def get_text(tweet)
    tweet.full_text
  end
end