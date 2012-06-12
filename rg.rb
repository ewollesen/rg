#!/usr/bin/env ruby

require "json"
require "yaml"
require "time"
require "open-uri"
require "colorize"


MS_PER_S = 1000


def check_server(server_record)
  server_name, base_url = server_record
  url = URI.parse(base_url)

  url.path = "/rest/projects"
  json = JSON.load(open(url))

  json["projects"].inject([]) do |e, project|
    e << [server_name, *process_project(project)]
  end
end

def process_project(project)
  timestamp = Time.at(project["lastBuild"]["timeStamp"] / MS_PER_S)
  passing = project["lastBuild"]["result"] == "SUCCESS"
  [project["title"], timestamp.ctime, passing]
end

def render_report(passing, failing)
  puts "#{passing.size}".colorize(:green) + " builds passing"
  unless failing.empty?
    puts "#{failing.size}".colorize(:red) + " builds failing"
  end
  failing.sort_by {|x| x.map(&:to_s).map(&:downcase)}.each do |(server, title, date, _)|
    puts "%-11s %-40s\t%s" % ["#{server}:", title.colorize(:red), date]
  end
end

def servers
  path = File.expand_path("~/.rg.yaml")
  servers = YAML.load(open(path))["servers"]
rescue Errno::ENOENT => e
  $stderr.puts "Could not find server file: #{path}"
  exit 1
rescue StandardError => e
  $stderr.puts "Error: #{e.class} #{e}"
  exit 1
end

if $0 == __FILE__
  passing, failing = servers.inject([]) do |l, server|
    l += check_server(server)
  end.partition {|r| r[3]}

  render_report(passing, failing)
end
