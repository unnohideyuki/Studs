def pre_block_html(s, punc_mode)
  s = CGI.escapeHTML(s)
  "<pre>#{s}</pre>\n"
end

def pre_block_latex(s, punc_mode)
  "\\begin{verbatim}\n#{s}\n\\end{verbatim}\n"
end
