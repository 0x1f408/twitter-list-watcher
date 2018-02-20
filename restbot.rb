#!/usr/bin/env ruby
# Driver for twitter-list-watcher
# todo: implement logging
# todo: re-implement Restbot#RetweetFromQueue
# todo: clean up configuration
# todo: make filter action customizable
# todo: greater list customizability
require 'twitter'
require 'yaml'
require 'date'
require 'logger'
require './lib/tweet_parser'

# Load configuration files
begin
  conf = YAML.load_file('config/config.yml')
  keys = YAML.load_file('config/keys.yml')
  rtlist = File.open("logs/rtlist.log", "w")
rescue Errno::ENOENT
  puts "#{$!} : configuration file not found"
  exit(1)
end

begin
  # Create Twitter Client & provide appropriate access keys
  client = Twitter::REST::Client.new do |config|
    config.consumer_key		      = keys['con_key']
    config.consumer_secret		  = keys['con_sec']
    config.access_token		      = keys['acs_tkn']
    config.access_token_secret	= keys['acs_sec']
  end

  # Define our post queue and priority queue, and how often to post from either of those
  # defaults to 30 minutes and 10 minutes, respectively
  $queue = Queue.new
  queue_frequency = conf['Frequency']['queue_post'] ? conf['Frequency']['queue_post'] * 60 : 1800
  $priority_queue = Queue.new
  priority_queue_frequency = conf['Frequency']['priority_queue_post'] ? conf['Frequency']['priority_queue_post'] * 60 : 600
  priority_queue_timeout = 4 * 3600 # 4 hours

  # Define how often we want to run our search (default 10 minutes)
  list_check = conf['Frequency']['list_check'] ? conf['Frequency']['list_check'] * 60 : 600

  # Define our search configuration
  search_config = { :blacklist => conf['Blacklist'], :normal => conf['Normal'], :priority => conf['Priority' ]}

  # Define the location of the list we want to watch
  listowner = conf['Source']['list_owner']
  listname = conf['Source']['list_name']

  interrupt = false

  puts "Initialized at #{Time.now}."

  # Create thread to handle normal-priority retweets
  post_thread = Thread.start {
    puts "Starting post thread"
    while !@interrupt
      unless $queue.nil?
        puts "Retweeting NORMAL... Queue length: #{$queue.length}\tLast retweet ID: #{$retweets.last}"
        next_post = $queue.pop

        # Did we already retweet this?
        if $retweets.include? next_post.id
          puts "Already retweeted that, trying again"
          next
        end

        begin
          client.retweet!(next_post)
          $retweets << next_post.id
          rtlist << "#{next_post.id}\n"
          puts "Retweeted #{next_post} at #{Time.now} with priority NORMAL.\n\t #{next_post.created_at}: #{next_post.text}"

        rescue Twitter::Error::AlreadyRetweeted, Twitter::Error::Forbidden
          puts "Already retweeted that!"
          rtlist << "#{next_post.id}\n"
          sleep(120) and next
        rescue Twitter::Error::NotFound
          puts "Tweet not found"
          sleep(120) and next
        end
        sleep(queue_frequency)
      end
    end
  }

  # Create thread to handle high-priority retweets
  priority_thread = Thread.start {
    puts "Starting post thread"
    while !interrupt
      unless $priority_queue.nil?
        puts "Retweeting PRIORITY... Queue length: #{$priority_queue}\tLast retweet ID: #{$retweets.last}"
        puts $priority_queue.length
        next_post = $priority_queue.pop

        # Did we already retweet this?
        if $retweets.include? next_post.id
          puts "Already retweeted that, trying again"
          next
        end

        # If a timeout is defined, is our tweet older than it?
        if priority_queue_timeout
          tweet_age = Time.now - next_post.created_at
          next if tweet_age > priority_queue_timeout
        end

        begin
          client.retweet!(next_post)
          $retweets << next_post.id
          rtlist << "#{next_post.id}\n"
          puts "Retweeted #{next_post} at #{Time.now} with priority HIGH.\n\t #{next_post.created_at}: #{next_post.text}"

        rescue Twitter::Error::AlreadyRetweeted, Twitter::Error::Forbidden
          puts "Already retweeted that!"
          rtlist << "#{next_post.id}\n"
          sleep(120) and next
        rescue Twitter::Error::NotFound
          puts "Tweet not found"
          sleep(120) and next
        end
        sleep(priority_queue_frequency)
      end
    end
  }

  tp = TweetParser.new(search_config)
  last_parsed = nil

  search_thread = Thread.start {
    while !interrupt
      # Grab a list of tweets
      results = client.search("list:#{listowner}/#{listname} exclude:replies exclude:retweets")
      puts "Running search at #{Time.now}..."

      # Test each of the tweets in the list we just retrieved
      i = 0
      q_count = 0
      pq_count = 0
      results.each { |result|
        # For the first of any given set of tweets, grab its numerical id
        $first_parsed = result.id if i ==0

        # Break if our current tweet is older than the newest tweet of the last iteration
        # of this thread
        break if (!last_parsed.nil? && result.id <= last_parsed)

        # Get the return code from TweetParser#Parse
        # Expected values:
        #   -1  tweet matches blacklist content
        #   0   tweet matches no content
        #   1   tweet matches normal-priority content
        #   2   tweet matches high-priority content
        retcode = tp.parse(result)
        case retcode
          when -1
            0 # log that tweet was blacklisted
          when 0
            0 # do nothing
          when 1
            $queue << result
            q_count+=1
          when 2
            $priority_queue << result
            pq_count+=1
          else
            retcode # log unexpected value received
        end
        i+=1
      }
      last_parsed = $first_parsed
      puts "#{q_count} \tadded to queue NORMAL" if q_count
      puts "#{pq_count} \tadded to queue PRIORITY" if pq_count
      sleep(list_check)
    end

  }

  post_thread.join
  priority_thread.join
  search_thread.join

rescue Twitter::Error::TooManyRequests
  puts "Too many requests!"
rescue Twitter::Error::Unauthorized
  puts "Invalid credentials"
ensure
  puts "Shutting down"
  rtlist.close unless rtlist.nil?
  #logger.close unless logger.nil?
  if $!
    puts "Reason: #{$!}"
  end
end