#!/usr/bin/env ruby

require "nokogiri"
require "open-uri"
require "time"
require "colorize"
require "ruby-debug"


def first_word(title)
  title.gsub(/\s.*/, "")
end

def render_pass(title, date)
  puts "PASS:".colorize(:green) + " #{first_word(title)}"
end

def render_fail(title, date)
  puts "FAIL:".colorize(:red) + " #{first_word(title)} (as of #{date})"
end

def print_heading(heading, out=$stdout)
  out.puts
  out.puts "=" * heading.size
  out.puts heading
  out.puts "=" * heading.size
end

def title_indicates_passing?(title)
  passing_re = [/\(stable\)$/,
                /\(back to normal\)$/]
  passing_re.any? {|re| re === title}
end

def title_indicates_failure?(title)
  failing_re = [/\(broken since[^\)]+\)$/]
  failing_re.any? {|re| re === title}
end

def title_indicates_building?(title)
  building_re = [/\(?\)$/]
  building_re.any? {|re| re === title}
end

def previous_build_successful?(entry)
  url = "http" + entry.at("id").text.split("http").last + "rssAll"

  Nokogiri.XML(open(url)).search("entry").each do |e|
    title = entry.at("title").text

    return true if title_indicates_passing?(title)
    return false if title_indicates_failure?(title)
  end

  false
end

def determine_if_passing?(entry)
  title = entry.at("title").text

  title_indicates_passing?(title) ||
    (title_indicates_building?(title) && previous_build_successful?(entry))
end

def check_server(server_record)
  name, url = server_record

  Nokogiri.XML(open(url)).search("entry").inject([]) do |e, i|
    title = i.at("title").text
    date = Time.parse(i.at("updated").text)
    passing = determine_if_passing?(i)

    e << [name, title, date, passing,]
  end
end

if $0 == __FILE__
  servers = {
    "Sprint" => "http://ci-sprint.lmpcloud.com:8080/rssLatest",
    "Production" => "http://ci-production.lmpcloud.com:8080/rssLatest",
  }
  passing, failing = servers.inject([]) do |l, server|
    l += check_server(server)
  end.partition {|r| r[3]}

  puts "#{passing.size}".colorize(:green) + " builds passing"
  unless failing.empty?
    puts "#{failing.size}".colorize(:red) + " builds failing"
  end
  failing.sort_by {|x| x.map(&:to_s).map(&:downcase)}.each do |(server, title, date, _)|
    puts "%-11s %-40s\t%s" % ["#{server}:", first_word(title).colorize(:red), date.localtime]
  end
end
