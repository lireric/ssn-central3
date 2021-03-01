require "logging.console"
require "ssnactions"

tmp_loadstring = loadstring -- save loadstring (corrupted in compat53 module)
require "ssnmqtt"
loadstring = tmp_loadstring -- restore 

require "ssnconf"

require "ssnUtils"
-- require "table"

local ltn12 = require "ltn12"
local yaml = require('yaml')
local http=require("socket.http");
SOCKET = require("socket")

-- global variables:
LOGLEVEL = logging.DEBUG
LOGGERGLOBAL = logging.console()
ssnmqttClient = nil
local CONF = nil
local mySSNACTIONS = nil


-- local chank variables:
local logger = LOGGERGLOBAL


-- ................................. POSTGREST API
--
function callPostgrestData(table, filter, method, request_body)
  local res, code, response_headers
  local filter_str = filter or ""
  local url = CONF.app.POSTGRESTURL .. "/" .. table .. "?" .. filter_str
  local response_body = {}

  if (method == 'GET' or method == 'DELETE') then
    res, code, response_headers = http.request {
      url = url,
      method = method,
      headers = {
          ["Content-Type"] = "application/json",
          ["Content-Length"] = 0
      },
      source = nil,
      sink = ltn12.sink.table(response_body)
      }
  else
      res, code, response_headers = http.request {
      url = url,
      method = method,
      headers = {
          ["Content-Type"] = "application/json",
          ["Content-Length"] = #request_body
      },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(response_body)
      }
  end
  return response_body
end

-- ==================================================================
-- Get object id from DB:
--
function getObjByDevice(dev)
  local obj = nil
  if (dev) then
    local filter = "account=eq." .. tostring(CONF.ssn.ACCOUNT) .. "&device=eq." .. dev .. "&limit=1"

    local res = callPostgrestData("devices", filter, "GET", nil)

    if (type(res) == "table") then
        logger:debug("response_body = %s", table.concat(res))
        obj = res.object
    end
  end
  return obj
end

function deviceSetValue(acc, obj, dev, channel, value, action_id, dev_ts)
  logger:debug ("deviceSetValue: acc=%d, obj=%d, dev=%s,  channel = %d, value = %s, action_id = %d", acc, obj, dev, channel, tostring(value), action_id)
  local ts = os.time(os.date("!*t"))
  if (not dev_ts) then
    dev_ts = ts
  end

  local req_json_str = '[{"td_account":' .. tostring(acc) .. ',"td_object":' .. tostring(obj) .. ',"td_device":"' .. tostring(dev) .. '","td_channel": ' .. channel ..
  ',"td_dev_ts":' .. dev_ts .. ',"td_store_ts":' .. ts .. ',"td_dev_value":' .. value .. ',"td_action":0}]'

  logger:debug("req_json_str = %s", req_json_str)

  local response = callPostgrestData("ssn_teledata", nil, "POST", req_json_str)

  if (type(response) == "table") then
      logger:debug("response_body = %s", table.concat(response))
  else
    logger:debug("response_body = %s", response)
  end
end

local function ssnOnMessage(mid, topic, payload)
    logger:debug("MQTT message. Topic=%s : %s", topic, payload)
    local acc
    local rootToken
    local subTokensArray
    acc, rootToken, subTokensArray = parseTopic(topic)
    -- check for correct account
    if not acc then
        logger:debug ("Wrong topic [%s]. Skipping", topic)
        return
    end
    if (acc == CONF.ssn.ACCOUNT) then
        logger:debug ("Account=%d, rootToken = %s", acc, rootToken)
        if (rootToken == "raw_data") then
            logger:info("Process  raw_datas")
    --      ssnRowDataProcess(payload)
        elseif (rootToken == "obj") then
            logger:info("Process  obj")
            if (subTokensArray) then
                local topic_map = parseTokenArray(rootToken, subTokensArray)
                if (topic_map) then
                    if (rootToken == "obj" and topic_map.subToken == "device" and topic_map.action == "out") then
                        logger:info("topic_map rootToken: %s, subToken: %s, device: %s, channel: %d, action: %s", topic_map.rootToken, topic_map.subToken, topic_map.device, topic_map.channel, topic_map.action)
                        local obj = topic_map.obj
                        local dev = topic_map.device
                        local channel = topic_map.channel
                        local ts = os.time(os.date("!*t")) -- TO DO...
                        logger:info("sending device value to DB storing webservice: %s[%s]=%s", dev, channel, payload, ts)

                        deviceSetValue(acc, obj, dev, channel, tonumber(payload), 0)

                    elseif (rootToken == "obj" and topic_map.subToken == "device" and topic_map.action == "out_json") then
                        logger:debug("out_json: = %s", payload)
                        -- TO DO ...
                        -- local teleData = yaml.load(payload)
                        -- logger:debug("JsonTeledataMsg: = %s", yaml.dump(teleData))
                    elseif (rootToken == "obj" and topic_map.subToken == "commands") then
                        logger:info("Process  commands. rootToken: %s, subToken: %s", topic_map.rootToken, topic_map.subToken)
                        -- TO DO ...
                    end
                end
            end
        elseif (rootToken == "bot") then -- TO DO (or may by in other place...)
            logger:info("Process  telegram bot")
        -- ssnTlgDataProcess(subTokensArray, payload)
        end
    else
        logger:debug ("Wrong account [%d]. Skipping", acc)
    end
end

local function mqpersistOnConnect(success, rc, str)
    if not success then
      logger:error("Failed to connect: %d : %s\n", rc, str)
      ssnmqttClient.conn_state = 0
      sleep(1.0)
      logger:debug("try to connect once more...")
      ssnmqttClient:connect()
      return
    end
    ssnmqttClient.conn_state = 1
    logger:info("MQTT connected: %s, %d, %s", tostring(success), rc, str)
    -- subscribe only to ours topics: 
    ssnmqttClient.client:subscribe("/ssn/acc/"..tostring(ssnmqttClient.account).."/obj/+/device/+/+/out", 0)
--    ssnmqttClient.client:subscribe("/ssn/acc/"..tostring(ssnmqttClient.account).."/obj/+/device/+/+/out_json", 0)
-- TO DO: subscribe to bot topic...
  end

-- ==================================================================
local function mainLoop (co)
    while true do
--        logger:debug("Start MQTT consumer")
        if (ssnmqttClient) then
            ssnmqttClient.client:loop(0,5)
            sleep(0.3)
        end
    end
  end

-- ******************************* local loop:
local function localLoop()
    logger:debug("Create local Loop coroutine")
    return coroutine.create(function ()
        sleep(0.3)
        coroutine.yield(nil, nil)
    end)
  end

-- Callback functions for actions module:
-- Get device value:
local function GetDV(dev, channel)
  logger:debug ("*** testGetDV: dev=%s, channel=%d", dev, channel)
  return 123
end
-- Set device value:
local function SetDV(dev, channel, value, action_id)
  logger:debug ("*** testSetDV: dev=%s, channel=%d, value=%s, action_id=%d", dev, channel, tostring(value), action_id)
  local ts = os.time(os.date("!*t"))
  -- TO DO: may be not needed?
  local obj = CONF.sensors.obj
  ssnmqtt:publishSensorValue(obj, dev, channel, value, ts, action_id)
end


-- ==================================================================
local function main()



    -- process command line arguments:
    local opts = getopt( arg, "ldc" )
    if (opts.l) then
      if (opts.l == 'DEBUG') then
        LOGLEVEL = logging.DEBUG
      elseif (opts.l == 'INFO') then
        LOGLEVEL = logging.INFO
      elseif (opts.l == 'WARN') then
        LOGLEVEL = logging.WARN
      elseif (opts.l == 'ERROR') then
        LOGLEVEL = logging.ERROR
      end
    end
  
    LOGGERGLOBAL:setLevel(LOGLEVEL)
  
    local file_conf_name = "ssn_conf.yaml"
    if (opts.c) then
      file_conf_name = opts.c
    end
    logger:info("Using config file: %s", file_conf_name)
  
    CONF = loadSSNConf(file_conf_name)
    logger:debug("Application name: %s", CONF.app.name)


    ssnmqttClient = ssnmqtt:new(nil, CONF.ssn.ACCOUNT, CONF.app.MQTT_HOST, CONF.app.MQTT_PORT, CONF.app.MQTT_BROKER_CLIENT_ID.."persist")
    if (ssnmqttClient) then
        logger:info("MQTT client created successefully")
        ssnmqttClient.client:login_set(CONF.app.MQTT_BROKER_USER, CONF.app.MQTT_BROKER_PASS)
    
        ssnmqttClient:setCallBackOnConnect (mqpersistOnConnect)
        ssnmqttClient:setCallBackOnMessage (ssnOnMessage)
        ssnmqttClient:connect()
    else 
        logger:error("MQTT client not created!")
    end




    mySSNACTIONS = ssnactions:new(self, CONF.ssn.ACCOUNT, GetDV, SetDV, CONF.actions)
    -- mySSNACTIONS:fillActions (CONF.actions)


    mainLoop(localLoop())
  end
  
main()
