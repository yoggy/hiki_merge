#!/usr/bin/ruby
require 'hiki/db/ptstore'
require 'fileutils'
require 'kconv'
require 'cgi'
require 'optparse'
require 'pp'

$KCODE = "e"

def get_page_names(src_dir, dst_dir)
  src_info_db_path = src_dir + "/info.db"
  raise "info.db not found...path=#{src_info_db_path}" unless File.exist?(src_info_db_path)

  src_pages = nil
  src_db = PTStore.new(src_dir + "/info.db")
  src_db.transaction(true) do
    src_pages = src_db.roots
  end

  dst_pages = nil
  dst_db = PTStore.new(dst_dir + "/info.db")
  dst_db.transaction(true) do
    dst_pages = dst_db.roots
  end

  target_pages = []
  confrict_pages = []

  src_pages.each do |k|
    if dst_pages.include?(k)
      confrict_pages << k
    else
      target_pages << k
    end
  end

  [target_pages, confrict_pages]
end

def copy_info_db(src_dir, target_pages, dst_dir)
  src_db = PTStore.new(src_dir + "/info.db")
  dst_db = PTStore.new(dst_dir + "/info.db")

  src_db.transaction do 
    dst_db.transaction do
      target_pages.each do |k|
        dst_db[k] = src_db[k]
      end
    end
  end
end

def copy_text(src_dir, target_pages, dst_dir)
  # mkdir
  FileUtils.mkdir_p(dst_dir + "/text")
  FileUtils.mkdir_p(dst_dir + "/cache/attach")

  #
  target_pages.each do |k|
    puts "process #{CGI.unescape(k).toutf8}"

    # copy text file
    src_text_path = src_dir + "/text/" + k
    dst_text_path = dst_dir + "/text/" + k
    FileUtils.cp_r(src_text_path, dst_text_path)

    # copy attached file
    src_attach_dir = src_dir + "/cache/attach/" + k
    dst_attach_dir = dst_dir + "/cache/attach/" + k
    if File.exist?(src_attach_dir)
       FileUtils.cp_r(src_attach_dir, dst_attach_dir)
    end
  end

end

# main
if __FILE__ == $0
  src_dir = ""
  dst_dir = ""
  test_run = false

  ARGV.options do |opt|
    opt.on('-s VAL', 'source hiki data directory')            {|v| src_dir = v}
    opt.on('-d VAL', 'merge destination hiki data directory') {|v| dst_dir = v}
    opt.on('-t',     'test run mode')                         {|v| test_run = true}

    opt.parse!
  end

  if src_dir == "" || dst_dir == ""
    puts ARGV.options
    exit 1
  end

  (target_pages, confrict_pages) = get_page_names(src_dir, dst_dir)

  unless test_run
    copy_info_db(src_dir, target_pages, dst_dir)
    copy_text(src_dir, target_pages, dst_dir)
  end

  puts "==== confrict_pages ===="
  puts confrict_pages.map{|k|CGI.unescape(k).toutf8}
end

