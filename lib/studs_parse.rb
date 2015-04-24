# -*- coding: utf-8 -*-

require 'lib/studs_parse_html.rb'
require 'lib/studs_parse_latex.rb'

def parse_list(parser, pends, punc_mode)
  r = parser.open_list_div

  lv = -1
  kind = :none
  stack = []

  pends.each do |s|
    if   /^(\s*)[\*\-\+]/ =~ s # unordered item
      newlv = count_level($1)

      if (newlv == lv)
        r << parser.close_item
        if kind != :ul
          r << parser.close_ol
          r << parser.open_ul
          kind = :ul
        end
        r << parser.emit_item(s, punc_mode)
      elsif newlv > lv
        stack.unshift [lv, kind] unless kind == :none
        r << parser.open_ul
        r << parser.emit_item(s, punc_mode)
        lv = newlv
        kind = :ul
      elsif newlv < lv
        r << parser.close_item
        while newlv < lv
          r << (kind == :ul ? parser.close_ul : parser.close_ol)
          lv, kind = stack.shift
        end

        if kind != :ul
          r += parser.close_ol
          r += parser.open_ul
          kind = :ul
        end
        r += parser.emit_item(s, punc_mode)
      end

    else /^(\s*)\d/ =~ s       # ordered item
      newlv = count_level($1)

      if (newlv == lv)
        r << parser.close_item
        if kind != :ol
          r << parser.close_ul
          r << parser.open_ol
          kind = :ol
        end
        r << parser.emit_item(s, punc_mode)
      elsif newlv > lv
        stack.unshift [lv, kind] unless kind == :none
        r << parser.open_ol
        r << parser.emit_item(s, punc_mode)
        lv = newlv
        kind = :ol
      elsif newlv < lv
        r << parser.close_item
        while newlv < lv
          r += (kind == :ul ? parser.close_ul : parser.close_ol)
          lv, kind = stack.shift
        end

        if kind != :ol
          r << parser.close_ul
          r << parser.open_ol
          kind = :ol
        end
        r << parser.emit_item(s, punc_mode)
      end
    end
  end
  
  r += (kind == :ul ? parser.close_ul : parser.close_ol)
  while stack.size > 0
    lv, kind = stack.shift
    r += (kind == :ul ? parser.close_ul : parser.close_ol)
  end
  r += parser.close_list_div
  r
end

def count_level(s)
  spaces = s || ""
  spaces.size
end


def parse(dat, conf, fmt=:html)
  parser = if fmt == :html
             ParserHTML.new(conf)
           else
             ParseLaTeX.new(conf)
           end

  title = nil
  stylesheet = "stylesheets/default.css"
  punc_mode = nil

  m = :init
  pends = nil
  str = ""
  n = 1

  dat += "\n \n" # to make it always end with an empty line.

  dat.split(/\n/).each do |s|
    if m == :init

      ## directive
      if /^{-#\s*(\w+):\s*(.*)\s*-}\s*$/ =~ s 
        cmd = $1
        arg = $2

        if cmd == "title"
          title = arg
        elsif cmd == "theme"
          stylesheet = fmt == :html ? parser.get_theme_css_name(arg) : ""
        elsif cmd == "punctuation"
          punc_mode = arg
        end

      ## begin a block command
      elsif /^\$\$<(\w+)>{/ =~ s 
        pends = s + "\n"
        m = :block

      ## heading
      elsif /^(#+)\s*(.*)$/ =~ s 
        lv = $1.size
        arg = $2
        str += parser.heading(lv, arg, n)
        n += 1

      ## skip empty lines
      elsif /^\s*$/ =~ s 
        # nothing

      ## list
      elsif /^\s*([\*\-\+]|\d[\d\.]*)\s/ =~ s
        pends = [s]
        m = :list

      ## begin a paragraph
      else
        m = :paragraph
        pends = [s]
      end

    elsif m == :block
      ## end of block
      if /^\$\$}\s*$/ =~ s 
        cmd = pends.slice(/^\$\$<(\w+)>{/, 1).strip
        arg = pends.gsub(/^\$\$<\w+>{/, '')
        str += parser.parse_block(cmd, arg, punc_mode)
        m = :init
      else
        pends += s + "\n"
      end

    elsif m == :paragraph
      ## empty line: end of paragraph
      if /^\s*$/ =~ s 
        str += parser.parse_paragraph(pends, punc_mode)
        m = :init
      else
        pends << s
      end

    elsif m == :list
      ## empty line: end of list
      if /^\s*$/ =~ s 
        str += parse_list(parser, pends, punc_mode)
        m = :init
      else
        pends << s
      end
      
    end
  end

  str += parser.flush_footnotes

  [title, str, stylesheet]
end
