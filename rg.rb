#!/usr/bin/env ruby

require "json"
require "yaml"
require "time"
require "open-uri"
require "colorize"


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
  timestamp = Time.at(project["lastBuild"]["timeStamp"] / 1000)
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

if $0 == __FILE__
  servers = {
    "Sprint" => "http://ci-sprint.lmpcloud.com:8080/",
    "Production" => "http://ci-production.lmpcloud.com:8080/",
  }
  servers = YAML.load(open(File.expand_path("~/.rg.yaml")))
  passing, failing = servers.inject([]) do |l, server|
    l += check_server(server)
  end.partition {|r| r[3]}

  render_report(passing, failing)
end
