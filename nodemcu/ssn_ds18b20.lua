

local function readout(temps)
    if t.sens then
      print("Total number of DS18B20 sensors: ".. #t.sens)
      for i, s in ipairs(t.sens) do
        print(string.format("  sensor #%d address: %s%s",  i,
          ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format(s:byte(1,8)),
          s:byte(9) == 1 and " (parasite)" or ""))
        end
    end
  
    for addr, temp in pairs(temps) do
      dev_id = string.format("%s", ('%02X-%02X%02X%02X%02X%02X%02X%02X'):format(addr:byte(1,8)))
      print(string.format("Sensor %s: %s °C", dev_id, temp))
      if CLIENT_PUB then
        CLIENT_PUB:publish("/ssn/acc/3/obj/147/device/"..dev_id.."/0/out", tonumber(temp), 0, 0, function(client) print("sent temperature") end)
      end
    end
  
    -- Module can be released when it is no longer needed
    --t = nil
    --package.loaded["ds18b20"]=nil
  end

  --  t = require("ds18b20")
--  pin_t = 3 -- gpio0 = 3, gpio2 = 4

--  tmr.create():alarm(60000, tmr.ALARM_AUTO, function()
--     print ("timer DS18B20")
--     t.sens={}
--     t:read_temp(readout, pin_t)
--   end)