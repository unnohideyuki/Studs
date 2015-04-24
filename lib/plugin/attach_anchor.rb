def attach_anchor_inline_html(s)
  str, name = s.split(/,/)
  buf =  "<a href=\"#{@conf.cgi_url}?page=#{@conf.page_name}&amp;cmd=dl&amp;n=#{name.strip}\">"
  buf << "#{str.strip}</a\n>"
  buf
end

def attach_anchor_inline_latex(s)
  str, name = s.split(/,/)
  str.strip
end
