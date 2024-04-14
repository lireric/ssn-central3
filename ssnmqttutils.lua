if not logger then
    -- Meta class logger mockup
    if not LOGLEVEL then LOGLEVEL = "INFO" -- default
    end
    if LOGLEVEL == "DEBUG" then LOGLEVEL_N = 0
      elseif LOGLEVEL == "INFO" then LOGLEVEL_N = 1
      elseif LOGLEVEL == "WARN" then LOGLEVEL_N = 2
      else LOGLEVEL_N = 3
    end
logger = {
        debug = function(f, ...) if LOGLEVEL_N == 0 then print ("DEBUG: ", string.format(arg[1], unpack(arg, 2))) end end,
        info =  function(f, ...) if LOGLEVEL_N <= 1 then print ("INFO: ", string.format(arg[1], unpack(arg, 2))) end end,
        warn =  function(f, ...) if LOGLEVEL_N <= 2 then print ("WARN: ", string.format(arg[1], unpack(arg, 2))) end end,
        error = function(f, ...) if LOGLEVEL_N <= 3 then print ("ERROR: ", string.format(arg[1], unpack(arg, 2))) end end
    }
end

-- ==================================================================
-- Helpers:

-- String split to array
function csplit(str,sep)
    local ret={}
    local n=1
    for w in str:gmatch("([^"..sep.."]*)") do
       ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
       if w=="" then
          n = n + 1
       end -- step forwards on a blank but not a string
    end
    return ret
 end
 
 --  Slice array
 function slice(tbl, first, last, step)
   local sliced = {}
 
   for i = first or 1, last or #tbl, step or 1 do
     sliced[#sliced+1] = tbl[i]
   end
 
   return sliced
 end
 
 -- Parse topic string into array
 -- return: account, root token, array of subtokens or nil if empty
 -- if topic structure wrong, account = nil
 function parseTopic(topic)
   logger:debug ("parseTopic. start")
   local topicArray = csplit(topic,"/")
   local offset = 0
   local account
   if ((topicArray[1] == "") and (topicArray[2]=="ssn") and (topicArray[3]=="acc")) then
     offset = 4 -- if topic like "/ssn/acc..."
   elseif ((topicArray[1]=="ssn") and (topicArray[2]=="acc")) then
     offset = 3 -- if topic like "ssn/acc..."
   else
     return nil
   end
   account = tonumber(topicArray[offset], 10)
   local rootToken = topicArray[(offset+1)]
   logger:debug ("parseTopic. size=%d,  account [%d] offset=%d rootToken=%s", #topicArray, account, offset, rootToken)
 --  print ("ARR1: "..topicArray[1], " ARR2: "..topicArray[2], " ARR3: "..topicArray[3])
   return account, rootToken, slice(topicArray, (offset+2))
 end
 
 -- Parse tokens array, getted after the parsing topic
 -- input: rootToken ["obj", "bot", "raw_data"... etc ]
 --        subTokensArray - tokens array
 -- return: map of specific for rootToken attributes
 --
 function parseTokenArray(rootToken, subTokensArray)
   logger:debug ("parseTokenArray. rootToken=%s, length subTokensArray=%d", rootToken, #subTokensArray)
   local res = nil
   if (rootToken == "raw_data") then
     logger:info("Process raw_data")
   --     TO DO:
   elseif (rootToken == "obj") then
     logger:info("Process obj")
     if (subTokensArray) then
         local tokenArraySize = #subTokensArray
         logger:debug("subTokensArray size = %d", tokenArraySize)
         local obj_str = subTokensArray[1]
         local obj = tonumber(obj_str, 10)
         logger:debug("ObjDataProcess: obj=%d", obj)
         local subToken = subTokensArray[2]
         -- ssnObjDataProcess(subTokensArray, payload)
         if (tokenArraySize == 2) then
             if (subToken == "commands") then
                 logger:info("Process  commands")
                 res = {rootToken = rootToken, subToken = subToken, obj = obj}
                 -- TO DO:
             end
         elseif (tokenArraySize == 3) then
             if (subToken == "commands") then
                 res = {rootToken = rootToken, subToken = subToken, command = subTokensArray[3], obj = obj}
             end
         elseif (tokenArraySize == 5) then
             if (subToken == "device") then
                 local dev = subTokensArray[3]
                 local channel = subTokensArray[4]
                 -- action may be "in", "out", "out_json"... etc:
                 res = {obj = obj, rootToken = rootToken, subToken = subToken, device = dev, channel = channel, action = subTokensArray[5]}
             end
         end
     end
   elseif (rootToken == "bot") then
     logger:info("telegram bot")
     local subToken = subTokensArray[2]
     res = {rootToken = rootToken, subToken = subToken}
   end
   return res
 end

-- fill map of devices: {key: dev_type}
-- input: CONF.sensors map
function fillDeviceTypesMap(conf_sensors)
  local device_map = {}
  local dev_id, dev_type
  if conf_sensors then
    for key,val in pairs(conf_sensors) do
      dev_type = key
      if key == "bmp180" then
          dev_id = val.id
          device_map[dev_id] = dev_type
        elseif key == "gpio" then
          dev_id = val.id
          device_map[dev_id] = dev_type
        elseif key == "ds18b20" then
          for i,val_ds in ipairs(val.devices) do
            device_map[val_ds.id] = dev_type
          end
        elseif key == "watchdog_tcp" then
          for i,val_wd in ipairs(val.destinations) do
            device_map[val_wd.id] = dev_type
          end
        end
      end
  end
  logger:info("DeviceTypesMap filled, size: %d", #device_map)
  return device_map
  end
