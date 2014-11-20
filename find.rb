#!/usr/bin/env ruby

GITHUB_BASE_URL = "https://github.com"
GITHUB_API_BASE_URL = "https://api.github.com"

def getForkUrl(fork)
  if fork[:name] == "#{fork[:owner][:login]}.github.io" and fork[:default_branch] == "master"
    "https://#{fork[:name]}"
  else
    "https://#{fork[:owner][:login]}.github.io/#{fork[:name]}"
  end
end

def jparse(json)
  JSON.parse(json, :symbolize_names=>true)
end

def cachedOpen(url, dir="cache")
  fname = File.join(dir, url.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, ''))
  if File.exist? fname
    File.open(fname, "rb").read
  else
    p "opening #{url} to #{fname}"
    Dir.mkdir dir if not Dir.exists? dir
    resp = open(url).read
    File.open(fname, 'w') { |file| file.write(resp) }
    resp
  end
end

def getForkedRepos(repo)
  repoPath = "#{repo[:owner][:login]}/#{repo[:name]}"
  JSON.parse(cachedOpen(File.join(GITHUB_API_BASE_URL, 'repos', repoPath, 'forks')), :symbolize_names=>true)
end

def getReposViaSearch(searchterm, pageLimit=3)
  ## finds repo links by pulling search term pages
  def getLinks(page)
    urls = []
    page.css('div.code-list-item').each do |res|
      urls << res.css('p.title a')[0]["href"]
    end
    urls
  end

  doc = Nokogiri::HTML(cachedOpen(File.join(GITHUB_BASE_URL, "search?q=#{searchterm}&type=Code&utf8=%E2%9C%93")))
  aurls = getLinks(doc)
  for i in 1..pageLimit
    nurl = doc.css('a.next_page')[0]
    break if nurl.nil?
    doc = Nokogiri::HTML(cachedOpen(File.join(GITHUB_BASE_URL,nurl["href"])))
    aurls.concat getLinks(doc)
  end

  aurls.map {|u| jparse cachedOpen(File.join(GITHUB_API_BASE_URL, 'repos', u)) }
end


if __FILE__==$0
  require 'open-uri'
  require 'json'
  require 'nokogiri'
  require 'set'

  findRepo = "t413/SinglePaged"

  repo = jparse cachedOpen(File.join(GITHUB_API_BASE_URL, 'repos', findRepo))

  foundForks = getForkedRepos(repo)
  foundForks.each { |fork| fork[:pageurl]=getForkUrl(fork) }
  foundForks.sort! { |a,b| a[:pageurl].downcase <=> b[:pageurl].downcase }

  foundSearches = getReposViaSearch(URI::encode('"subtlecircle sectiondivider imaged"'))
  foundSearches.each { |i| i[:pageurl]=getForkUrl(i) }
  foundSearches.sort! { |a,b| a[:pageurl].downcase <=> b[:pageurl].downcase }

  puts "got #{foundForks.length} direct forks, #{foundSearches.length} search results"

  used = File.open("used.txt", "rb").read.split(/\n/).to_set
  ignored = []

  puts "forks:"
  foundForks.each do |fork|
    if not used.include? fork[:html_url]
      desc = (fork[:description] != repo[:description]) ? "\t[ #{fork[:description]} ]" : ""
      puts "#{fork[:pageurl]} \t-> #{fork[:full_name]} #{desc}"
    else
      ignored << fork
    end
  end

  puts "\n\nsearches:"
  foundSearches.each do |i|
    if not used.include? i[:html_url]
      puts "#{i[:pageurl]} \t-> #{i[:full_name]} #{i[:description]}"
    else
      ignored << i
    end
  end

  puts "\n\nignored:", ignored.map {|i| i[:full_name]}


  #p JSON.pretty_generate(content)
end
