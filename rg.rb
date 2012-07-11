#!/usr/bin/env ruby

require "json"
require "yaml"
require "time"
require "open-uri"
require "colorize"


MS_PER_S = 1000
BUILD_STATUSES = [
                  "SUCCESS",
                  "FAILURE",
                  "ABORTED",
                  nil,
                 ]

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
  [project["title"], timestamp.ctime, project["lastBuild"]["result"]]
end

def render_report(statuses)
  puts "#{statuses["SUCCESS"].size}".colorize(:green) + " builds passing"
  failures = statuses.fetch("FAILURE", [])
  unless failures.empty?
    puts "#{failures.size}".colorize(:red) + " builds failing"
  end
  failures.sort_by {|x| x.map(&:to_s).map(&:downcase)}.each do |(server, title, date, _)|
    puts "%-11s %-40s\t%s" % ["#{server}:", title.colorize(:red), date]
  end
  aborted = statuses.fetch("ABORTED", [])
  unless aborted.empty?
    puts "#{statuses["ABORTED"].size}".colorize(:default) + " builds aborted"
  end
  aborted.sort_by {|x| x.map(&:to_s).map(&:downcase)}.each do |(server, title, date, _)|
    puts "%-11s %-40s\t%s" % ["#{server}:", title.colorize(:default), date]
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
  statuses = servers.inject([]) do |l, server|
    l += check_server(server)
  end
  statuses = statuses.inject({}) do |s, r|
    s.update(r[3] => (s.fetch(r[3], []) << r))
  end

  render_report(statuses)
end
