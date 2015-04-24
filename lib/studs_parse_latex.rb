# -*- coding: utf-8 -*-
require 'uri'

class ParseLaTeX
  def initialize(conf)
    @conf = conf
    load_plugins
  end

  def load_plugins
    Dir::glob("lib/plugin/*.rb") do |file|
      File::open(file.untaint) do |src|
        instance_eval(src.read.untaint, "(lib/plugin/#{File::basename(file)})", 1)
      end
    end
  end

  def heading(lv, arg, n)
    r = "<%= heading#{lv > 3 ? 3 : lv} %>"
    
    if /\s*(\d\d\d\d-\d\d-\d\d)\s*/ =~ arg
      arg = DateTime.parse($1).strftime("%Y-%m-%d (%a)")
    end

    r << "{#{escapeLaTeX2(arg.strip)}}\n"
    r
  end
  
  def inline_cmd(cmd, arg)
    case cmd 
    when "ref"
      k = arg.gsub(/(^\s+)|(\s+$)/, '')
      "~\\ref{#{k}}"
    when "verb"
      k = arg.gsub(/(^\s+)|(\s+$)/, '')
      k = k.gsub(/\|/, '\\|')
      "\\verb|#{k}|"
    when "fn"
      s = parse_string(arg, nil)
      "\\footnote{#{s}}"
    else
      instance_eval("#{cmd}_inline_latex(arg)")
    end
  end

  def flush_footnotes
    "" # nothing todo for LaTeX
  end

  def escapeLaTeX(s)
    s = s.gsub(/\\/, '\textbackslash ') # should do first
    s = s.gsub(/%/, '\\\%')
    s = s.gsub(/\_/, '\\_')
    s = s.gsub(/\[/, '\\verb|[|')
    s = s.gsub(/\]/, '\\verb|]|')
    s = s.gsub(/\~/, '\~{}')
    s = s.gsub(/>/, '\\verb|>|')
    s = s.gsub(/</, '\\verb|<|')
    s = s.gsub(/\$([^<])/, '\$\1')
    s
  end

  # TODO: Dirty Hack!, \verb cannot be in heading 
  def escapeLaTeX2(s)
    s = s.gsub(/\\/, '\textbackslash ') # should do first
    s = s.gsub(/%/, '\\\%')
    s = s.gsub(/\_/, '\\_')
    s = s.gsub(/\~/, '\~{}')
    s
  end

  def parse_string(s, punc_mode)
    a = s.split(/(\$<\w+>{[^\}]*})|(\\\(.*?\\\))|(\*\*.*?\*\*)|(\!?\[[^\]]*?\]\(.*?\))/, -1)

    b = a.map do |s|
      if /\$<(\w+)>{([^\}]*)}/ =~ s
        inline_cmd($1, $2)
      elsif /\\\(.*?\\\)/ =~ s # inline Math
        s
      elsif /\*\*(.*?)\*\*/ =~ s # bold face
        s = escapeLaTeX($1)
        "{\\bf #{s}}"
      elsif /(\!?)\[([^\]]*?)\]\((.*?)\)/ =~ s
        bang = $1
        txt = $2
        url = $3

        s = ""
        if bang == "!"
          alt = parse_string(txt, punc_mode)
          if /^http/ =~ url
            s  = external_image(url, alt)
          else
            s  = attached_image(url, alt)
          end
        else
          s  = escapeLaTeX(txt)
          if /^http/ =~ url
            s += "\\footnote{\\url{#{url}}}"
          end
        end
        s
      else
        escapeLaTeX(s)
      end
    end

    b.join
  end

  def treatdm(s)
    r = ""
    if /\$<eqtag>/ =~ s
      r = s.gsub(/\\\[/, "\\begin{eqnarray}").gsub(/\\\]/, "\\end{eqnarray}").gsub(/\$<eqtag>{(\S+)}/, '\label{\1}')
    else
      r = s
    end

    r.gsub(/(\n)+/, "\n") # remove empty lines
    r
  end

  def parse_paragraph(ss, punc_mode)
    r = ""
    dm = ""
    m = :init

    ss.each do |s|
      if m == :init
        if /^\\\[/ =~ s
          m = :dm
          dm = s
        else
          r += parse_string(s, punc_mode)
          r += "\n" # do not delete this. a white space is expected here.
        end
      else
        if /^\\\]/ =~ s
          dm += s
          r += treatdm(dm)
          m = :init
        else
          dm += s
        end
      end
    end
    r += "\n"
    r
  end

  def parse_ol(ss, punc_mode)
    r = "\\begin{enumerate}\n"
    ss.each do |s|
      s = parse_string(s.gsub(/^\d+\./, ''), punc_mode)
      r += "\\item #{s}\n"
    end
    r += "\\end{enumerate}\n\n"
    r
  end

  def parse_ul(ss, punc_mode)
    r = "\\begin{itemize}\n"
    ss.each do |s|
      s = parse_string(s.gsub(/^\*+/, ''), punc_mode)
      r += "\\item #{s}\n"
    end
    r += "\\end{itemize}\n\n"
    r
  end

  def open_list_div
    ""
  end

  def close_list_div
    ""
  end

  def open_ul
    "\\begin{itemize}\n"
  end

  def close_ul
    "\\end{itemize}\n\n"
  end

  def open_ol
    "\\begin{enumerate}\n"
  end

  def close_ol
    "\\end{enumerate}\n\n"
  end

  def emit_item(s, punc_mode)
    s = s.gsub(/^\s*([\*\-\+]|\d[\d\.]*)\s/, '')
    s = parse_string(s, punc_mode)
    "\\item #{s}"
  end

  def close_item
    "\n"
  end

  def parse_block(c, s, punc_mode)
    instance_eval("#{c}_block_latex(s, punc_mode)")
  end

  def external_image(url, alt)
    @eimgnum ||= 1

    uri = URI.parse(url)
    extname = File.extname(uri.path)
    fname = "image#{@eimgnum}#{extname}"
    @eimgnum += 1

    page_name = @conf.page_name
    data_dir = @conf.data_dir
    wget = @conf.wget
    ebb = @conf.ebb

    dest = "#{data_dir}/latex/#{page_name}/extimg"
    system("mkdir -p #{dest}")
    system("cd #{dest}; #{wget} #{url} -O #{fname}")
    system("cd #{dest}; #{ebb} -x  #{fname}")

    "\\includegraphics[scale=0.5]{extimg/#{fname}}"
  end

  def attached_image(n, alt)
    @iimgnum ||= 1
    extname = File.extname(n)
    fname = "image#{@iimgnum}#{extname}"
    @iimgnum += 1
    
    page_name = @conf.page_name
    data_dir = @conf.data_dir
    wget = @conf.wget
    ebb = @conf.ebb

    src  = "#{data_dir}/attach/#{page_name}"
    dest = "#{data_dir}/latex/#{page_name}/intimg"
    system("mkdir -p #{dest}")
    system("cp #{src}/#{n} #{dest}/#{fname}")

    "\\includegraphics[scale=0.5]{intimg/#{fname}}"
  end
end
