# twitter-list-watcher

Easily monitor tweets to a specified list and automate interactions (retweets by default).

## Overview

Queries a Twitter list periodically and filter through any tweets returned by it. Tweets matching
filter criteria are added to various queues

## Installation

twitter-list-watcher was developed under Ruby 2.3.3

Install dependencies with Bundler: `bundle install`

Start with `ruby restbot.rb`.

#### Coming soon: 

* Init script

* Management/support via Web API

* Better documentation

## Use

Configuration files located under `/config`

* `config.yml` contains frequency & search configuration.
  * `Priority` defines high-priority terms to search for; these are generally on a shorter timer between retweets.
  * `Normal` defines normal-priority terms to search for.
  * `Blacklist` defines terms to exclude; if found, tweet is excluded from interactions.
* `keys.yml` contains API access information.

