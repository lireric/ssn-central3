require "ssnconf"
require "ssnPDU"
mqtt = require("mosquitto")
require "ssnUtils"


local logger
if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end
--local ssnmqttClient

-- Meta class
ssnmqtt = {
  brokerHost = "127.0.0.1",
  brokerPort = 1883,
  keepalive = 60,
  account = 0,
  client = nil,
  mqttID = "0",
  conn_state = 0, -- connection state: 1 - Ok
  last_conn_ts = 0,
  callBackMessage = nil,
  callBackOnConnect = nil
}

-- Derived class method new

function ssnmqtt:new (o, account, brokerHost, brokerPort, mqttID)
  logger:debug ("Creating new ssnmqtt instanse: account=%d, brokerHost=%s, brokerPort=%d, mqttID=%s", account, brokerHost, brokerPort, mqttID)
  o = o or {}
   setmetatable(o, self)
   self.__index = self
   self.account = account
   self.brokerHost = brokerHost or "127.0.0.1"
   self.brokerPort = brokerPort or 1883
   self.mqttID = mqttID
   self.client = mqtt.new(mqttID)
--   self.publishSensorValue = publishSensorValue
   return o
end


function ssnmqtt:setCallBackOnMessage (callBackFunc)
   self.callBackMessage = callBackFunc
   self.client.ON_MESSAGE = self.callBackMessage
end

function ssnmqtt:setCallBackOnConnect (callBackFunc)
   self.callBackOnConnect = callBackFunc
   self.client.ON_CONNECT = self.callBackOnConnect
end

function ssnmqtt:connect ()
   self.client:connect(self.brokerHost, self.brokerPort, self.keepalive)
end

function ssnmqtt:loop_forever ()
   self.client:loop_forever()
end


function ssnmqtt:cmdIniSend(payload, destObj)
    logger:debug ("Command INI-type: destObj=%d,  payload = %s", destObj, payload)
    sendSSNCommand(self, payload, 7, destObj)
end

function ssnmqtt:cmdJsonSend(payload, destObj)
    logger:debug ("Command JSON-type: destObj=%d,  payload = %s", destObj, payload)
    sendSSNCommand(self, payload, 2, destObj)
end

function ssnmqtt:cmdSDV(payload, obj, dev, channel)
  logger:debug("Set Data Value (obj=%d): d[%d,%d]=%s", obj, dev, channel, payload)
-- make set dev value command:
  local sdv = '{"ssn":{"v":1,"obj":'..obj..',"cmd":"sdv", "data": {"adev":'..dev..',"acmd":'..channel..',"aval":'..payload..'}}}"'
  sendSSNCommand(self, sdv, 2, obj)
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

-- ******************************************************************
function sendSSNCommand(ss, strCmd, nCmdType, destObj)
  local sP = ssnPDU:new(nil, destObj, ssnConf.ssn.proxy_obj, nCmdType, strCmd)
  ss.client:publish("/ssn/acc/"..tostring(ssnConf.ssn.ACCOUNT).."/obj/"..tostring(destObj).."/commands",
    sP:getSSNPDU(), 0, false)
end



local function ssnOnConnect(success, rc, str)
    if not success then
        logger:error("Failed to connect: %d : %s\n", rc, str)
        ssnmqttClient.conn_state = 0
        sleep(1.0)
        logger:debug("try to connect once more...")
        ssnmqttClient:connect()
    else
        ssnmqttClient.conn_state = 1
        logger:info("MQTT connected: %s, %d, %s", tostring(success), rc, str)
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/raw_data", 0)
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/obj/+/commands", 0)
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/obj/+/commands/ini", 0)
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/obj/+/commands/json", 0)
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/obj/+/device/+/+/in", 0)
        if (ssnConf.ssn.Use_Tlg_Bot == 1) then
            -- use Telegram bot module
            ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/telegram/in", 0)
            ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/telegram/in/photo", 0)
        end
        ssnmqttClient.client:subscribe("/ssn/acc/" .. tostring(ssnmqttClient.account) .. "/telegram/out", 0)
    end
end




-- Publish value to device topic:
-- input parameters: obj - source object; 
--                   dev, channel, value - device data; ts - timestamp (from device)
function ssnmqtt:publishSensorValue(obj, dev, channel, value, ts, action)
  logger:debug("Set device value (obj=%d): d[%s,%d]=%s", obj, tostring(dev), channel, value)

  local dev_topic = "/ssn/acc/"..tostring(self.account).."/obj/"..tostring(obj).."/device/"..tostring(dev).."/"..tostring(channel).."/out"
  logger:debug("topic: %s", dev_topic)

  self.client:publish(dev_topic, value, 0, false)

  -- publish full device data:
  if (not ts) then
    ts = os.time()
  end
  if (not action) then
    action = 0
  end

  local jsonDevData = '{"a":'..tostring(action)..',"d": "'..tostring(dev)..'","c":'..tostring(channel)
  ..',"v":'..tostring(value)..',"t":'..tostring(ts)..',"pub_ts":'..tostring(os.time())..'}'

  logger:debug("jsonDevData: %s", jsonDevData)

  self.client:publish(dev_topic.."_json",jsonDevData, 0, false)

  -- publish event information:
  if (action) then
    local topic = "/ssn/acc/"..tostring(self.account).."/obj/"..tostring(obj).."/event"
    self.client:publish(topic, jsonDevData, 0, false)
  end

end

-- ******************************************************************
function ssnmqtt:sendTelegramMessage(buf)
  if (buf) then
    logger:debug ("sendTelegramMessage: payload = %s", buf)
    self.client:publish("/ssn/acc/"..tostring(ssnConf.ssn.ACCOUNT).."/telegram/in", buf, 0, false)
  end
end
-- --------------------------------------------------- TO DO - use publishSensorValue instead this ..
-- publish device value data
-- input parameters: ss -  ssnmqtt client; srcObj - source object; 
--                   idDev, channelDev, valueDev - device data; ts - timestamp (from device)
function publishSSNDataDevice(ss, srcObj, idDev, channelDev, valueDev, ts, action)
  if (srcObj and idDev and channelDev) then
    logger:debug("publishSSNDataDevice: %d %d %d %d %d", srcObj, idDev, channelDev, valueDev, ts)
    local topic = "/ssn/acc/"..tostring(ssnConf.ssn.ACCOUNT).."/obj/"..tostring(srcObj)..
      "/device/"..tostring(idDev).."/"..tostring(channelDev).."/out"
    logger:debug("topic: %s", topic)

    -- publish short device data:
    ss.client:publish(topic,valueDev, 0, false)

    -- publish full device data:
    local jsonDevData = '{"a":'..tostring(action)..',"d":'..tostring(idDev)..',"c":'..tostring(channelDev)
    ..',"v":'..tostring(valueDev)..',"t":'..tostring(ts)..',"pub_ts":'..tostring(os.time())..'}'

    logger:debug("jsonDevData: %s", jsonDevData)

    ss.client:publish(topic.."_json",jsonDevData, 0, false)

    -- publish event information:
    if (action) then
      topic = "/ssn/acc/"..tostring(ssnConf.ssn.ACCOUNT).."/obj/"..tostring(srcObj).."/event"
      ss.client:publish(topic, jsonDevData, 0, false)
    end
  end
end

-- ---------------------------------------------------------------------------
local function ssnOnMessage(mid, topic, payload)
        logger:debug("Msg: %s, %s", topic, payload)
end

-- -------------------------------------------------------------------
-- for stand alone testing


local function main()

  ssnConf = loadSSNConf()
  if not ssnConf then
    logger:fatal(string.format("can't open config. Stop\n"))
    return
  end

  logger:info(string.format("SSNMQTT Module -- [Application name: %s]", ssnConf.app.name))

  ssnmqttClient = ssnmqtt:new(nil, ssnConf.ssn.ACCOUNT, ssnConf.app.MQTT_HOST, ssnConf.app.MQTT_PORT, ssnConf.app.MQTT_BROKER_CLIENT_ID)
--  ssnmqttClient.client:auth(ssnmqttClient, ssnConf.ssn.MQTT_BROKER_USER, ssnConf.ssn.MQTT_BROKER_PASS)
  ssnmqttClient:setCallBackOnConnect (ssnOnConnect)
  ssnmqttClient:setCallBackOnMessage (ssnOnMessage)
  ssnmqttClient.client:login_set(ssnConf.app.MQTT_BROKER_USER, ssnConf.app.MQTT_BROKER_PASS)

  ssnmqttClient:connect()
  sleep(1.0)
  --  ssnmqttClient:loop_forever()

  while true do
    -- try to connect if not connected:
    if (ssnmqttClient.conn_state == 0) then
      logger:debug("try to connect...")
      ssnmqttClient:connect()
      sleep(3.0)
    else
      ssnmqttClient.client:loop(0,1)
      -- os.execute("sleep 1")
      sleep(1.0)
    end
  end
end

--main()


