#!/usr/bin/ruby

require 'rubygems'
require 'logger'
require 'rss'
gem 'tinyurl'
require 'tinyurl'
gem 'twitter4r'
require 'twitter'

class Twitterss
  
  TWITTER_LIMIT = 140
  
  @@past_posts_file = File.join(ENV['HOME'], '.twitterss_history')
  
  def initialize(config_file, logger)
    @config = YAML.load(File.read(config_file))
    @logger = logger
    
    File.open(@@past_posts_file, "w").close if !File.exists?(@@past_posts_file)
    @past_posts = YAML.load(File.read(@@past_posts_file))
    @past_posts ||= {}
  end

  def run
    @config.each do |name, config|
      @logger.debug "#{name}:"
      @logger.debug "parsing #{config['rss']} "
      feed = RSS::Parser.parse(config['rss'])
      max = config['max'] || 5
      feed.items[0,max].each do |item|
        generate_message(item)
        
        if posted?(name, item)
          @logger.debug "\"#{item.title}\"...skipped"
        else
          twitter_client = Twitter::Client.new(:login => config['login'], :password => config['password'])
          twitter_client.status(:post, generate_message(item))
          
          mark_posted(name, item)
          @logger.debug "\"#{item.title}\"...posted"
        end
      end
      
    end
    dump_state!
  end  
  
  def self.dump_usage
    puts "Usage:"
    puts "  twitterss [-v] <configuration file>"
  end
  
private
  
  def get_tinyurl(url)
    Tinyurl.new(url).tiny
  end
  
  def posted?(name, item)
    @past_posts[name] ||= {}
    @past_posts[name][item.link]
  end
  
  def mark_posted(name, item)
    @past_posts[name] ||= {}
    @past_posts[name][item.link] = true
  end
  
  def dump_state!
    @logger.debug "dumping state..."
    File.open(@@past_posts_file, "w") do |f|
      YAML.dump(@past_posts, f)
    end
  end
  
  def generate_message(item)
    tinyurl = get_tinyurl(item.link)
    limit = TWITTER_LIMIT - tinyurl.length
    message = "#{item.title.strip}: #{item.description.to_s.strip}"[0,limit-2] # 2 for '..'
    message << "..#{tinyurl}"
    message
  end
end

config_file = ARGV[-1]
logger = Logger.new(STDOUT)
logger.level = ARGV.include?("-v") ? Logger::DEBUG : Logger::WARN

if config_file.nil? || config_file.empty?
  Twitterss.dump_usage
else
  twitterss = Twitterss.new(config_file, logger)
  twitterss.run
end