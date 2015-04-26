class TabularParser 
  def initialize(parent)
    @parent = parent

    @cols = nil
    @curr = 0
    @borders = {}
    @s = ""
    @cells = []
    @tab = []
    @opts = {}
  end

  def get_tokens(s)
    re = /(\\hline)|(\\cline\s*{[\d\-]+\})|(\s\&\s)|(\\\\)|(^:.*$)/
    s.split(re, -1).map{|s| s.chomp.gsub(/(^\s+)|(\s+$)/, '')}
  end

  def parse(s)
    get_tokens(s).each do |tok|
      atoken(tok)
    end
    @tab
  end

  def atoken(tok)
    if not @cols
      @cols = tok.split(//)
      # TODO: vlines
    elsif tok == "\\hline"
      1.upto(@cols.size) do |c|
        k = "h#{@curr}_#{c}"
        if @borders[k]
          @borders[k] = 2
        else
          @borders[k] = 1
        end
      end
    elsif /\\cline\s*{(\d+)-(\d+)}/ =~ tok
      c0 = $1.to_i
      c1 = $2.to_i
      c0.upto(c1) do |c|
        k = "h#{@curr}_#{c}"
        if @borders[k]
          @borders[k] = 2
        else
          @borders[k] = 1
        end
      end
    elsif tok == "&"
      @cells << @s
      @s = ""
    elsif tok == "\\\\"
      @cells << @s
      @s = ""
      @tab << @cells
      @cells = []
      @curr += 1
      # TODO: vlines
    elsif tok == ""
      # skip
    elsif /^:(\w+)\s+(.*)/ =~ tok
      @opts[$1] = $2
    else
      @s += tok
    end
  end

  def takebd(k)
    r = @borders[k]
    @borders[k] = nil
    r || 0
  end

  def emit(punc_mode)
    ret = "<div class=\"table\"><div class=\"tabular\">"
    ret << "<table\n>"

    if @opts["caption"]
      num = @parent.new_object_number

      ret << "<caption><strong>\u8868 #{num}: </strong\n>"
      ret << "#{@opts["caption"]}</caption\n>"

      if @opts["label"]
        @parent.insert_label(@opts["label"], num)
      end
    end

    @tab.each_with_index do |cells, i|
      row = i + 1
      ret << "<tr>"
      cells.each_with_index do |s, j|
        col = j + 1
        u = takebd("h#{row - 1}_#{col    }")
        d = takebd("h#{row    }_#{col    }")
        l = takebd("v#{row    }_#{col - 1}")
        r = takebd("v#{row    }_#{col    }")

        a = ['', 'b', 'd']
        clsstr = a[l] + @cols[col-1] + a[r] + "#{u}#{d}"

        s = @parent.parse_string(s, punc_mode)
        ret << "<td class=\"#{clsstr}\">#{s}</td\n>"
      end
      ret << "</tr>"
    end
    ret << "</table></div></div\n>"
    ret
  end
end

def table_block_html(s, punc_mode)
  tab = TabularParser.new(self)
  tab.parse(s)
  tab.emit(punc_mode)
end

def table_block_latex(s, punc_mode)
  opts = {}

  re = /(\\hline)|(\\cline\s*{[\d\-]+\})|(\s\&\s)|(\\\\)|(^:.*$)/
  a = s.split(re, -1).map{|s| s.chomp.gsub(/(^\s+)|(\s+$)/, '')}
  cols = a.shift

  tab = ""

  footnotes = []

  a.each do |s|
    if /^\\[hc]line/ =~ s
      tab += s + "\n"
    elsif s == "&"
      tab += " & "
    elsif s == "\\\\"
      tab += " \\\\\n"
    elsif /^:(\w+)\s+(.*)/ =~ s
      opts[$1] = $2
    else
      t = parse_string(s, punc_mode)
      t, fn = extr_footnotes(t)
      footnotes += fn
      tab += t.gsub(/\&/, '\\\&')
    end
  end

  r = "\\begin{table}[#{opts["pos"]}]\n"
  r << "\\centering\n"
  r << "\\caption{#{opts["caption"]}}\n" if opts["caption"]
  r << "\\label{#{opts["label"]}}\n" if opts["label"]
  r << "\\begin{tabular}{#{cols}}\n"
  r << tab
  r << "\\end{tabular}\n"
  r << "\\end{table}\n"

  if footnotes.size > 0
    r << "\\addtocounter{footnote}{-#{footnotes.size}}\n"
    footnotes.each do |s|
      r << "\\addtocounter{footnote}{1}\n"
      r << "\\footnotetext{#{s}}\n\n"
    end
  end

  r << "\n"
  r
end

def extr_arg(str)
  n = 1
  arg = ""
  rest = ""

  str.split(/({|})/, -1).each do |s|
    if n > 0
      case s
      when /{/
        n += 1
      when /}/
        n -= 1
      end
      arg << s if n > 0
    else
      rest << s
    end
  end

  [arg, rest]
end

def extr_footnotes(str)
  fn = []

  a = str.split(/(\\footnote\{)/, -1)
  t = a.shift || ""

  while a.size > 0
    cmd = a.shift
    s = a.shift
    arg, rest = extr_arg(s)
    t << '\footnotemark '
    t << rest
    fn << arg
  end

  [t, fn]
end
