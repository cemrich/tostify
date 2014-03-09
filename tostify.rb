#!/usr/bin/env ruby
# The MIT License (MIT)
# Copyright (c) 2014 Claudius Coenen
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# encoding: UTF-8
Encoding.default_external = Encoding::UTF_8 if RUBY_VERSION > '1.8.7'

require 'json'
require 'uri'
require 'net/http'
require 'fileutils'
require 'hpricot'
require 'chromatic'

Dir.chdir(File.dirname(__FILE__))
CONFIG = JSON.load(File.open('config.json', 'r'))
changed_pages = []

CONFIG['pages'].each do |page|
  uri = URI(page['url'])
  # defaults for each page
  page['name'] ||= uri.host
  page['persistent_name'] ||= page['name'] + '.txt'
  page['selector'] ||= "body"

  puts "#{page['name'].yellow}: #{uri}"
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.ca_file = "cacert.pem"
  end

  response = http.get(uri.path)
  if response["Content-Type"] =~ /charset=(.*)$/
    response.body.force_encoding($1)
  else
    response.body.force_encoding('UTF-8')
  end
  body = response.body.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
  body = Hpricot(body).search(page['selector']).inner_text.strip



  persistent_name = File.join(CONFIG['history'], page['persistent_name'])
  FileUtils.mkdir_p(File.dirname(persistent_name))
  File.open(persistent_name, 'wb') do |f|
    f << body
  end
  if `git status --porcelain "#{persistent_name}"`.strip.length > 0
    changed_pages << page['name']
    puts "  changed".red
  else
    puts "  unchanged".green
  end
end

if changed_pages.length > 0
  `git add #{CONFIG['history']}`
  `git commit -m "history changed for #{changed_pages.join(', ')}"`
  puts "=== changes ==="
  puts `git diff HEAD@{1}..HEAD`
end
