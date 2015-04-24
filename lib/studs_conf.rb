class Conf
  def initialize
    @public = false
  end

  def Conf.load(path)
    c = new()
    c.instance_eval(File.read(path))
    c
  end

  def set_public
    @public = true
  end

  def cgi_name
    @cgi_programs ||= ['index.cgi', 'editor.cgi']

    if @public
      @cgi_programs[0]
    else
      @cgi_programs[1]
    end
  end

  def cgi_url
    "#{@base_url}/#{cgi_name}"
  end

  def set_page_name(page_name)
    @page_name = page_name
  end

  def plugin_params
    @plugin_params ||= {}
    @plugin_params
  end

  attr_reader :base_url
  attr_reader :data_dir
  attr_reader :lib_dir
  attr_reader :plugin_dir
  attr_reader :wget
  attr_reader :page_name
  attr_reader :ebb
  attr_reader :convert
  attr_reader :platex
  attr_reader :dvipdfmx
  attr_reader :public
end
