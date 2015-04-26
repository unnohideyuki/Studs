STUDS_VERSION = "0.1"

STUDS_COMMANDS = [ "view", 
                 "edit",
                 "save", 
                 "new",  
                 "pages",
                 "src",
                 "texraw",
                 "tex",
                 "log1",
                 "log2",
                 "dbg",
                 "dvi", 
                 "pdf", 
                 "dl",
                 "upload"
                 ]

require 'cgi'
require 'erb'
require 'time'
require 'lib/studs_parse.rb'
require 'lib/studs_mime.rb'

def save_page(page_name, contents, public_mode, data_dir)
  open("#{data_dir}/text/#{page_name}.txt", "w") do |f|
    f.flock(File::LOCK_EX)
    f.puts(contents)
  end

  pubfile = "#{data_dir}/text/#{page_name}.public"
  if public_mode
    open(pubfile, "w").close
  else
    File.unlink(pubfile) if File.exist?(pubfile)
  end
end

def save_file(page_name, fname, body, data_dir)
  bname = File.basename(fname)
  dest = "#{data_dir}/attach/#{page_name}/"
  system ("mkdir -p #{dest}")

  open("#{dest}/#{bname}", "w") do |f|
    f.flock(File::LOCK_EX)
    f.write(body)
  end
end

def list_attach_files(page_name, data_dir, cgi_url)
  dir = "#{data_dir}/attach/#{page_name}/"

  r = "<ul>\n"
  Dir.glob("#{dir}/*").sort.each do |path|
    if File.file?(path)
      name = File.basename(path)
      r << "<li><a href=\"#{cgi_url}?page=#{page_name}&cmd=dl&n=#{name}\">#{name}</a></li>"
    end
  end
  r << "</ul>"
  r
end

def makepdf(page_name, data_dir)
  system("mkdir -p #{data_dir}/latex/#{page_name}")
  system("bin/mkpdf #{page_name} 1> #{data_dir}/latex/#{page_name}/mkpdf.log 2>&1")
end

def get_pages(data_dir, cgi_url)
  r = ""
  Dir.glob("#{data_dir}/text/*.txt").each do |s|
    pn = s.slice(%r!text/([\w\-]+).txt$!, 1)
    pub = File.exist?("#{data_dir}/text/#{pn}.public") ? "" : "(private)"
    r << "<li><a href=\"#{cgi_url}?page=#{pn}\">#{pn}</a> #{pub}</li>\n" if pn
  end
  r
end

def debug_info(cgi, page_name, data_dir)
  tex  = "#{data_dir}/latex/#{page_name}/#{page_name}.tex"
  dvi  = "#{data_dir}/latex/#{page_name}/#{page_name}.dvi"
  pdf  = "#{data_dir}/latex/#{page_name}/#{page_name}.pdf"
  log1 = "#{data_dir}/latex/#{page_name}/#{page_name}.log"
  log2 = "#{data_dir}/latex/#{page_name}/mkpdf.log"

  texdate = nil
  dvidate = nil
  pdfdate = nil
  log1date = nil
  log2date = nil
  
  open(tex){|f| texdate = f.mtime.httpdate} if File.exist?(tex)
  open(dvi){|f| dvidate = f.mtime.httpdate} if File.exist?(dvi)
  open(pdf){|f| pdfdate = f.mtime.httpdate} if File.exist?(pdf)
  open(log1){|f| log1date = f.mtime.httpdate} if File.exist?(log1)
  open(log2){|f| log2date = f.mtime.httpdate} if File.exist?(log2)

  template = open("lib/template/debug_info.erb").read
  html = ERB.new(template).result(binding)
  cgi.out { html }
end

def page_visible?(conf, page_name)
  data_dir = conf.data_dir

  page_exist   = File.exist?("#{data_dir}/text/#{page_name}.txt") 
  page_permission = 
    (not conf.public) || File.exist?("#{data_dir}/text/#{page_name}.public")

  page_exist and page_permission
end

def studs_view(cgi, conf)
  params = cgi.params
  data_dir = conf.data_dir
  cgi_url = conf.cgi_url

  page_name = params["page"][0] || "FrontPage"
  conf.set_page_name(page_name)

  menu_template = if conf.public
                    open("lib/template/public_menu_html.erb").read
                  else
                    open("lib/template/private_menu_html.erb").read
                  end

  if page_visible?(conf, page_name)

    title, body, stylesheet = read_cache(conf, page_name, data_dir)

    unless title
      conf.lock_htmlgen
      dat = open(text_file_path(page_name, data_dir)).read
      title, body, stylesheet, labels = parse(dat, conf, :html)
      title, body, stylesheet, x = parse(dat, conf, :html, labels) if labels
      title ||= page_name
      write_cache(conf, page_name, data_dir, title, body, stylesheet)
      conf.unlock_htmlgen
    end

    mt = get_mtime(page_name, data_dir).httpdate

    menu = ERB.new(menu_template).result(binding)
    template = open("lib/template/singlepage_html.erb").read
    html = ERB.new(template).result(binding)
    cgi.out("Last-Modified" => mt){ html }
  else
    cgi.out("status" => "NOT_FOUND") {"Page Not Found"}
  end
end

def text_file_path(page_name, data_dir)
  "#{data_dir}/text/#{page_name}.txt"
end

def get_mtime(page_name, data_dir)
  mt = nil
  File.open(text_file_path(page_name, data_dir)) do |f|
    mt = f.mtime
  end
  mt
end

def cache_file_path(conf, page_name, data_dir)
  # public and private mode must use different cache file
  # because they use different url for the cgi.
  if conf.public
    "#{data_dir}/cache/#{page_name}.public"
  else
    "#{data_dir}/cache/#{page_name}.private"
  end
end

def cache_valid?(conf, page_name, data_dir)
  r = false
  text_path = "#{data_dir}/text/#{page_name}.txt"
  cache_path = cache_file_path(conf, page_name, data_dir)

  if File.exist?(cache_path)
    File.open(text_path, 'r') do |ft|
      File.open(cache_path, 'r') do |fc|
        r = true if fc.mtime > ft.mtime
      end
    end
  end
  r
end

def write_cache(conf, page_name, data_dir, title, body, stylesheet)
  cache_path = cache_file_path(conf, page_name, data_dir)

  dst = File.dirname(cache_path)
  system("mkdir -p #{dst}")

  File.open(cache_path, 'w') do |f|
    f.flock(File::LOCK_EX)
    f.puts(title)
    f.puts(stylesheet)
    f.write(body)
  end
end

def read_cache(conf, page_name, data_dir)
  cache_path = cache_file_path(conf, page_name, data_dir)

  r = [nil, nil, nil]

  if cache_valid?(conf, page_name, data_dir)
    File.open(cache_path, 'r') do |f|
      title = f.gets
      stylesheet = f.gets
      body = f.read
      r = [title, body, stylesheet]
    end
  end

  r
end

def privchk(conf)
  raise "permission denied." if conf.public
end

def studs_edit(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  cgi_url = conf.cgi_url

  page_name = params["page"][0]
  cgi_url = conf.cgi_url

  raise "illegal page name: #{page_name}" unless /^[\w\-]+$/ =~ page_name

  attach_files = list_attach_files(page_name, data_dir, cgi_url)

  dat = ""
  if File.exist?("#{data_dir}/text/#{page_name}.txt")
    f = open("#{data_dir}/text/#{page_name}.txt")
    dat = f.read
    f.close
  end

  publicmode = File.exist?("#{data_dir}/text/#{page_name}.public") ? "checked" : ""

  template = open("lib/template/editpage_html.erb").read
  html = ERB.new(template).result(binding)

  cgi.out { html }
end

def studs_save(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  cgi_url = conf.cgi_url

  page_name = params["page"][0]
  contents  = params["contents"][0]

  conf.set_page_name(page_name)
  conf.lock_htmlgen
  save_page(page_name, contents, params["public_mode"][0], data_dir)
  conf.unlock_htmlgen

  makepdf(page_name, data_dir)

  template = open("lib/template/saving_html.erb").read
  html = ERB.new(template).result(binding)

  cgi.out { html }
end

def studs_new(cgi, conf)
  privchk(conf) ## only for Editor mode.

  template = open("lib/template/createpage_html.erb").read
  html = ERB.new(template).result(binding)
  cgi.out { html }
end

def studs_pages(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  cgi_url = conf.cgi_url

  pages = get_pages(data_dir, cgi_url)
  template = open("lib/template/listpages_html.erb").read
  html = ERB.new(template).result(binding)
  cgi.out { html }
end

def studs_src(cgi, conf)
  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]

  if page_visible?(conf, page_name)
    dat = open("#{data_dir}/text/#{page_name}.txt").read
    cgi.out("content-type" => "text/plain; charset=UTF-8") { dat }
  else
    cgi.out("status" => "NOT_FOUND") {"Page Not Found"}
  end
end

def studs_texraw(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  dat = open("#{data_dir}/latex/#{page_name}/#{page_name}.tex").read
  cgi.out("content-type" => "text/plain; charset=UTF-8") { dat }
end

def studs_tex(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  lines = open("#{data_dir}/latex/#{page_name}/#{page_name}.tex").read.split(/\n/)
  lno = 0
  dat = lines.map{|s| lno +=1; "\t#{lno}:\t#{s}"}.join("\n")
  cgi.out("content-type" => "text/plain; charset=UTF-8") { dat }
end

def studs_log1(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  dat = open("#{data_dir}/latex/#{page_name}/#{page_name}.log").read
  cgi.out("content-type" => "text/plain; charset=UTF-8") { dat }
end

def studs_log2(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  dat = open("#{data_dir}/latex/#{page_name}/mkpdf.log").read
  cgi.out("content-type" => "text/plain; charset=UTF-8") { dat }
end

def studs_dbg(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  debug_info(cgi, page_name, data_dir)
end

def studs_dvi(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]

  dviname = "#{data_dir}/latex/#{page_name}/#{page_name}.dvi"

  if File.exist?(dviname)
    f = open(dviname)
    dat = f.read
    mt = f.mtime.httpdate
    f.close

    cgi.out("Content-Type" => "application/x-dvi",
            "Content-Disposition" => "attachment; filename*=US-ASCII''#{page_name}.dvi",
            "Last-Modified" => mt
            ) { dat }
  else
    debug_info(cgi, page_name, data_dir)
  end
end

def studs_pdf(cgi, conf)
  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]

  pdfname = "#{data_dir}/latex/#{page_name}/#{page_name}.pdf"

  if page_visible?(conf, page_name)
    if File.exist?(pdfname)
      f = open(pdfname)
      dat = f.read
      mt = f.mtime.httpdate
      f.close

      cgi.out("Content-Type" => "application/pdf",
              "Content-Disposition" => "attachment; filename*=US-ASCII''#{page_name}.pdf",
              "Last-Modified" => mt
              ) { dat }
    else
      debug_info(cgi, page_name, data_dir)
    end
  else
    cgi.out("status" => "NOT_FOUND") {"Page Not Found"}
  end
end

def studs_dl(cgi, conf)
  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0]
  fname = params["n"][0]
  path = "#{data_dir}/attach/#{page_name}/#{fname}"

  if page_visible?(conf, page_name)
    if File.exist?(path)
      f = open(path)
      dat = f.read
      mt = f.mtime.httpdate
      f.close

      mtype = detect_mimetype(fname)
      cgi.out("Content-Type" => mtype,
              "Content-Disposition" => "attachment; filename*=US-ASCII''#{File.basename fname}",
              "Last-Modified" => mt
              ) { dat }
    else
      raise "#{path} not found."
    end
  else
    cgi.out("status" => "NOT_FOUND") {"Page Not Found"}
  end
end

def studs_upload(cgi, conf)
  privchk(conf) ## only for Editor mode.

  params = cgi.params
  data_dir = conf.data_dir
  page_name = params["page"][0].read
  body  = params["attachfile"][0].read
  fname = params["attachfile"][0].original_filename

  save_file(page_name, fname, body, data_dir)

  template = open("lib/template/saving_html.erb").read
  html = ERB.new(template).result(binding)
  cgi.out { html }
end

def cmd_check(cmd)
  raise "illegal command: #{cmd}"  unless STUDS_COMMANDS.include?(cmd)
end

def cgi_main(cgi, conf)
  params = cgi.params

  cmd = if cgi.multipart?
          params["cmd"][0].read
        else
          params["cmd"][0] || "view"
        end

  cmd_check(cmd)
  instance_eval("studs_#{cmd}(cgi, conf)")
end
