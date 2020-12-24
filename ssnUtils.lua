require "socket"

-- From http://lua-users.org/wiki/AlternativeGetOpt
-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

function sleep(s)
  socket.sleep(s)
end

-- Start command by OS and return it OUT
function sys_command(command)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  return string.sub(result, 1, -2)
end

function get_log_level_from_str(l)
  res = logging.ERROR
  if (l == 'DEBUG') then
    LOGLEVEL = logging.DEBUG
  elseif (l == 'INFO') then
    LOGLEVEL = logging.INFO
  elseif (l == 'WARN') then
    LOGLEVEL = logging.WARN
  elseif (l == 'ERROR') then
    LOGLEVEL = logging.ERROR
  end
  return res
end

-- input: gpio section of config
--        dev_id
-- return: map of device info or nil
--   
function get_gpio_dev_info(gpio_sect, dev_id)
  for k, v in ipairs(gpio_sect.pins) do
    if (v.id == dev_id) then
      return v
    end
  end
  return nil
end
