def fig_block_html(args, punc_mode)
  fname = ""
  num = nil
  caption = nil

  args.split(/\n/).each do |s|
    case s = s.strip
    when /^:label\s+(.*)/
      k = $1
      num = new_object_number unless num
      insert_label(k, num)
    when /^:caption\s+(.*)/
      caption = $1
      num = new_object_number unless num
    when /^[^:](\S+)/
      fname = s
    end
  end

  n = fname
  if /\.pdf/i =~ File.extname(fname)
    fname2 = fname.gsub(/\.pdf$/i, '.png')
    n = "fig/#{fname2}"

    convert = @conf.convert
    attach_dir = "#{@conf.data_dir}/attach/#{@conf.page_name}"
    system("mkdir -p #{attach_dir}/fig > /dev/null 2>&1")
    system("cd #{attach_dir}; #{convert} #{fname} #{n} > /dev/null 2>&1")
  end

  buf = "<div class=\"figure\">\n"
  buf << "<img src=\"#{@conf.cgi_url}?page=#{@conf.page_name}&amp;cmd=dl&amp;n=#{n}\" />"
  buf << "<p><b>\u56f3 #{num}</b>: #{caption}</p>" if caption
  buf << "</div>\n"
  buf
end

def fig_block_latex(args, punc_mode)
  @plugin_fig_n ||= 1

  fname = label = caption = pos = opts = nil

  args.split(/\n/).each do |s|
    case s = s.strip
    when /^:label\s+(.*)/
      label = $1
    when /^:caption\s+(.*)/
      caption = $1
    when /^:pos\s+(.*)/
      pos = $1
    when /^:opts\s+(.*)/
      opts = $1
    when /^[^:](\S+)/
      fname = s
    end
  end


  attach_dir = "#{@conf.data_dir}/attach/#{@conf.page_name}"
  latex_dir = "#{@conf.data_dir}/latex/#{@conf.page_name}"

  n = "f#{@plugin_fig_n}.pdf"
  @plugin_fig_n += 1
  src = "#{attach_dir}/#{fname}"
  dst = "#{latex_dir}/fig/"
  system("mkdir -p #{dst}")

  ebb = @conf.ebb
  convert = @conf.convert

  if /\.pdf/i =~ File.extname(fname)
    system("cp #{src} #{dst}/#{n}")
  else
    system("mkdir -p #{latex_dir}/fig > /dev/null 2>&1")
    system("#{convert} -resample 600 -units PixelsPerInch #{src} #{dst}/#{n} > /dev/null 2>&1")
  end

  system("#{ebb} -x #{dst}/#{n}")

  buf = "\n\\begin{figure}[#{pos || ""}]\n" 
  buf << "\\centering\n"
  buf << "\\includegraphics[#{opts||""}]{fig/#{n}}\n"
  buf << "\\caption{#{caption}}\n" if caption
  buf << "\\label{#{label}}\n" if label
  buf << "\\end{figure}\n\n"
  buf
end
