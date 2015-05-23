# -*- coding: utf-8 -*-
require 'cgi'
require 'date'

class ParserHTML
  def initialize(conf)
    @conf = conf

    @chapter_number = nil
    @obj_number = 1
    @obj_labels = {}

    @diary_current_date = nil
    @diary_subheading_num = nil
    @diary_num_notes = nil

    @footnotes = []
    @unresoleved_reference = false

    load_plugins
  end

  attr_reader :unresoleved_reference
  attr_accessor :obj_labels

  def load_plugins
    Dir::glob("lib/plugin/*.rb") do |file|
      File::open(file.untaint) do |src|
        instance_eval(src.read.untaint, "(lib/plugin/#{File::basename(file)})", 1)
      end
    end
  end

  def get_theme_css_name(arg)
    theme = arg.gsub(/^\s+/, '').gsub(/\s+$/, '')
    "stylesheets/#{theme}/#{theme}.css"
  end

  def heading(lv, arg, n)
    # TODO: range check for lv
    name = "p#{n}"
    if @diary_current_date and @diary_subheading_num
      name = "#{@diary_current_date}p#{@diary_subheading_num}"
      @diary_subheading_num += 1
    end

    r = ""

    if /\s*(\d\d\d\d-\d\d-\d\d)\s*/ =~ arg
      dstr = $1
      r += flush_footnotes
      @diary_current_date = name =dstr
      @diary_num_notes = 1
      @diary_subheading_num = 0
      arg = DateTime.parse(dstr).strftime("%Y-%m-%d (%a)")
    end

    r += "<div class=\"header\"\n" 
    r += "><h#{lv}  id=\"#{name}\"><a href=\"##{name}\"\n"
    r += ">#{arg}</a></h#{lv}></div\n"
    r += ">"
    r
  end

  def inline_cmd(cmd, arg)
    r = ""
    if cmd == "ref"
      k = arg.gsub(/(^\s+)|(\s+$)/, '')

      @obj_labels ||= {}
      n = @obj_labels[k]

      if n
        r = "&nbsp;#{n}"
      else
        @unresoleved_reference = true
        r = "<strong>{<em>Error: label not found: #{k}</em>}</strong>"
      end
    elsif cmd == "eqtag"
      k = arg.gsub(/(^\s+)|(\s+$)/, '')
      num = new_object_number
      insert_label(k, num)
      r = "\\tag{#{num}}"
    elsif cmd == "verb"
      c = parse_string(arg, nil)
      r = "<span class=\"verb\">#{c}</span>\n"
    elsif cmd == "fn"
      r = footnote(arg)
    else
      begin
        r = instance_eval("#{cmd}_inline_html(arg)")
      rescue => e
        r = "<strong>Error in $&lt;#{cmd}&gt;</strong>\n"
        r += "<!-- #{e} -->\n"
        r += "<!-- #{e.backtrace.join("\n")}  -->"
      end
    end
    r
  end

  def flush_footnotes
    r = ""

    if @footnotes.size > 0
      r << "<div class=\"notes\"><ul\n>"

      @footnotes.each do |n, m, s|
        r << "<li id=fn#{n}><a href=\"#fnref#{n}\">*#{m}</a>: #{s}</li\n>"
      end

      r << "</ul></div\n>"
      @footnotes = []
    end

    r
  end

  def footnote(s)
    n = m = @footnotes.size + 1

    if @diary_current_date
      n = "#{@diary_current_date}n#{@diary_num_notes}"
      m = @diary_num_notes
      @diary_num_notes += 1
    end

    s = parse_string(s, nil)
    r = "<sup class=\"footnote\"><span id=\"fnref#{n}\">"
    r += "<a href=\"#fn#{n}\" title=\"#{s}\">*#{m}</a></span></sup>"
    @footnotes << [n, m, s]

    r
  end

  def parse_string(s, punc_mode)
    a = s.split(/(\$<\w+>{[^\}]*})/, -1)

    b = a.map do |s|
      if /\$<(\w+)>{([^\}]*)}/ =~ s
        inline_cmd($1, $2)
      else
        s = CGI.escapeHTML(s)
        s = s.gsub(/\*\*(.*?)\*\*/, '<b>\1</b>')
        s = s.gsub(/(\!?)\[([^\]]*?)\]\((\S*?)\)/) do |m|
          bang = $1
          txt = $2
          url = $3

          s = ""
          if bang == "!"
            alt = parse_string(txt, punc_mode)
            if /^http/ =~ url
              s = "<img src=\"#{url}\" alt=\"#{alt}\" title=\"#{alt}\"/>"
            else
              s = "<img src=\"#{@conf.cgi_url}?page=#{@conf.page_name}&amp;cmd=dl&amp;n=#{url}\" alt=\"#{alt}\" title=\"#{alt}\"/>"
            end
          else
            s  = "<a href=\"#{url}\">"
            s += parse_string(txt, punc_mode)
            s += "</a>"
          end
          s
        end

        if punc_mode && /^\s*conv\s*$/ =~ punc_mode
          s = s.gsub(/、/, "，").gsub(/。/, "．")
        end
        s
      end
    end

    b.join
  end

  def parse_paragraph(ss, punc_mode)
    r = "<div class=\"paragraph\"><p>"
    ss.each do |s|
      r += parse_string(s, punc_mode)
      r += "\n" # do not delete this. a white space is expected here.
    end
    r += "</p></div\n>"
    r
  end

  def open_list_div
    "<div class=\"paragraph\">"
  end

  def close_list_div
    "</div\n>"
  end

  def open_ul
    "<ul\n>"
  end

  def close_ul
    "</ul\n>"
  end

  def open_ol
    "<ol\n>"
  end

  def close_ol
    "</ol\n>"
  end

  def emit_item(s, punc_mode)
    s = s.gsub(/^\s*([\*\-\+]|\d+(?:\.\d+)*\.)\s/, '')
    s = parse_string(s, punc_mode)
    "<li>#{s}"
  end

  def close_item
    "</li\n>"
  end
  
  def new_object_number
    chap = @chapter_number ? "#{@chapter_number}." : ""
    r = "#{chap}#{@obj_number}"
    @obj_number += 1
    r
  end

  def insert_label(label_name, num)
    @obj_labels[label_name] = num
  end

  def parse_block(c, s, punc_mode)
    begin
      instance_eval("#{c}_block_html(s, punc_mode)")
    rescue => e
      r = "<strong>Error in $$&lt;#{c}&gt;</strong>\n"
      r += "<!-- #{e} -->\n"
      r += "<!-- #{e.backtrace.join("\n")}  -->"
    end
  end
end
