def kw_inline_html(arg)
  rb, rt = arg.split(/,/)
  "<ruby><b>#{rb}</b><rt>#{rt}</rt></ruby>"
end

def kw_inline_latex(arg)
  rb, rt = arg.split(/,/)
  r = "\\ruby{{\\bf #{rb}}}{#{rt}}"
end

