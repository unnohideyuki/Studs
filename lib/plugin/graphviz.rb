# graphviz plugin

def dot_block_html(s, punc_mode)
  @dotn ||= 1

  fname = "dot#{@dotn}"
  @dotn += 1

  data_dir = @conf.data_dir
  page_name = @conf.page_name

  dest = "#{data_dir}/attach/#{page_name}/dot"
  
  system("mkdir -p #{dest}")

  content = s
  open("#{dest}/#{fname}.dot", "w") do |f|
    f.write(s)
  end

  # should check mtime and suppress generation
  dot = @conf.plugin_params['graphviz:dot']
  system("cd #{dest}; #{dot} -T png -o #{fname}.png #{fname}.dot")

  s = "<div class=\"figure\">\n"
  s += "<img src=\"#{@conf.base_url}/#{@conf.cgi_name}?cmd=dl&amp;page=#{page_name}&amp;n=dot/#{fname}.png\" alt=\"#{content}\" title=\"#{content}\" /></div>\n"
  s
end

def dot_block_latex(s, punc_mode)
  @dotn ||= 1

  fname = "dot#{@dotn}"
  @dotn += 1

  data_dir = @conf.data_dir
  page_name = @conf.page_name

  dest = "#{data_dir}/latex/#{page_name}/dot"
  
  system("mkdir -p #{dest}")

  open("#{dest}/#{fname}.dot", "w") do |f|
    f.write(s)
  end


  # should check mtime and suppress generation
  dot = @conf.plugin_params['graphviz:dot']
  convert = @conf.convert
  ebb = @conf.ebb

  unless @conf.plugin_params['graphviz:dot-disable-pdf']
    system("cd #{dest}; #{dot} -T pdf -o #{fname}.pdf #{fname}.dot")
  else
    system("cd #{dest}; #{dot} -T svg -o #{fname}.svg #{fname}.dot")
    system("cd #{dest}; #{convert} -resample 300 -units PixelsPerInch #{fname}.svg #{fname}.pdf")
  end

  system("cd #{dest}; #{ebb} -x #{fname}.pdf")

  scale = @conf.plugin_params['graphviz:includegraphics-scale'] || "1.0"

  s = "\\begin{figure}[H]\n\\begin{center}\n"
  s << "\\includegraphics[scale=#{scale}]{dot/#{fname}.pdf}\n"
  s << "\\end{center}\n\\end{figure}\n"
  s
end
