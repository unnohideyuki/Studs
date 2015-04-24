require 'erb'

def math_block_html(content, punc_mode)
  @plugin_math_n ||= 1

  platex = @conf.platex
  dvipdfmx = @conf.dvipdfmx
  convert = @conf.convert

  data_dir = @conf.data_dir
  page_name = @conf.page_name
  plugin_dir = @conf.plugin_dir

  dest = "#{data_dir}/attach/#{page_name}/math"
  system("mkdir -p #{dest}")
  system("rm -f #{dest}/*")

  fname = "math#{@plugin_math_n}"
  @plugin_math_n += 1

  template = File.read("#{plugin_dir}/template/math_block_html.erb")
  tex = ERB.new(template).result(binding)

  open("#{dest}/#{fname}.tex", "w") do |f|
    f.write(tex)
  end

  system("cd #{dest}; #{platex} #{fname}  1> math.log 2>&1")
  system("cd #{dest}; #{dvipdfmx} #{fname} 1>> math.log 2>&1")
  system("cd #{dest}; #{convert} -trim -transparent white #{fname}.pdf #{fname}.png 1>> math.log 2>&1")

  s = "<div class=\"figure\">\n"
  s += "<img src=\"#{@conf.base_url}/#{@conf.cgi_name}?cmd=dl&amp;page=#{page_name}&amp;n=math/#{fname}.png\" alt=\"#{content}\" title=\"#{content}\" /></div>\n"
  s
end

def math_block_latex(content, punc_mode)
  "\n\\[\n#{content.strip}\n\\]\n"
end
