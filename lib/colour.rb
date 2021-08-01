# this file contains the colors require for the whole project 

def colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end
  
  def red(text)
    colorize(text, "\e[1m\e[31m")
  end
  
  def dark_red(text)
    colorize(text, "\e[31m")
  end
  
  def green(text)
    colorize(text, "\e[1m\e[32m")
  end
  
  def dark_green(text)
    colorize(text, "\e[32m")
  end
  
  def yellow(text)
    colorize(text, "\e[1m\e[33m")
  end
  
  def dark_yellow(text)
    colorize(text, "\e[33m")
  end
  
  def blue(text)
    colorize(text, "\e[1m\e[34m")
  end
  
  def dark_blue(text)
    colorize(text, "\e[34m")
  end
  
  def magenta(text)
    colorize(text, "\e[1m\e[35m")
  end
  
  def dark_magenta(text)
    colorize(text, "\e[35m")
  end
  
  def cyan(text)
    colorize(text, "\e[1m\e[36m")
  end
  
  def dark_cyan(text)
    colorize(text, "\e[36m")
  end
  
  def white(text)
    colorize(text, "\e[1m")
  end
  
  def grey(text)
    colorize(text, "\e[0m\e[22m")
  end