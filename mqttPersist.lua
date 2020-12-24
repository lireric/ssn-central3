require "logging.console"
require "ssnmqtt"
require "ssnconf"
require "ssnUtils"
local ltn12 = require "ltn12"
local yaml = require('yaml')
local http=require("socket.http");
SOCKET = require("socket")

-- global variables:
LOGLEVEL = logging.DEBUG
LOGGERGLOBAL = logging.console()
SSNMQTTCLIENT = nil
CONF = nil

-- local chank variables:
local logger = LOGGERGLOBAL

-- ==================================================================
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
                local tokenArraySize = #subTokensArray
                logger:debug("ObjDataProcess: %s, subTokensArray size = %d", payload, tokenArraySize)
                local obj_str = subTokensArray[1]
                local obj = tonumber(obj_str, 10)
                logger:debug("ObjDataProcess: obj=%d", obj)
                local subToken = subTokensArray[2]
                -- ssnObjDataProcess(subTokensArray, payload)
                if (tokenArraySize == 2) then
                    if (subToken == "commands") then
                        logger:info("Process  commands")
                        -- TO DO:
                    end
                elseif (tokenArraySize == 3) then
                    if ((subToken == "commands") and (subTokensArray[3]=="ini")) then
                        -- ssnmqttClient:cmdIniSend(payload, obj)
                        -- TO DO:
                    elseif ((subToken == "commands") and (subTokensArray[3]=="json")) then
                        -- ssnmqttClient:cmdJsonSend(payload, obj)
                        -- TO DO:
                    end
                elseif (tokenArraySize == 5) then
                    if (subToken == "device") then
                        local dev = tonumber(subTokensArray[3], 10)
                        local channel = subTokensArray[4]
                        local ts = os.time(os.date("!*t"))
                        if (subTokensArray[5]=="out") then
                            logger:info("sending device value to DB storing webservice: %d[%s]=%s", dev, channel, payload)
                            local req_json_str = '[{"td_account":' .. tostring(acc) .. ',"td_object":' .. obj_str .. ',"td_device":' .. tostring(dev) .. ',"td_channel": "' .. channel ..
                            '","td_dev_ts":' .. ts .. ',"td_store_ts":' .. ts .. ',"td_dev_value":' .. tonumber(payload) .. ',"td_action":0}]'
                            logger:debug("req_json_str = %s", req_json_str)
                            local request_body = req_json_str
                            local response_body = {}
                            local res, code, response_headers = http.request{
                                url = CONF.app.POSTGRESTURLTELEDATA,
                                method = "POST",
                                headers =
                                  {
                                      ["Content-Type"] = "application/json";
                                      ["Content-Length"] = #request_body;
                                  },
                                  source = ltn12.source.string(request_body),
                                  sink = ltn12.sink.table(response_body),
                            }
                            if (type(response_body) == "table") then
                                logger:debug("response_body = %s", table.concat(response_body))
                            end
                        elseif (subTokensArray[5]=="in") then
                        -- ssnmqttClient:cmdSDV(payload, obj, subTokensArray[3], subTokensArray[4])
                        -- TO DO:
                        end
                    end
                elseif ((subToken == "device") and (subTokensArray[5]=="out_json")) then
                    -- local teleData = yaml.load(payload)
                    -- logger:debug("JsonTeledataMsg: = %s", yaml.dump(teleData))
                    -- if (ssnDB1) then 
                    -- ssnDB1:saveTeledata(teleData, obj)
                    -- end
                    -- TO DO:
                end
            end
        elseif (rootToken == "telegram") then
            logger:info("Process  telegram")
        -- ssnTlgDataProcess(subTokensArray, payload)
        end
    else
        logger:debug ("Wrong account [%d]. Skipping", acc)
    end
end

-- ==================================================================
local function mainLoop (co)
    while true do
        logger:debug("Start MQTT consumer")
        if (SSNMQTTCLIENT) then
            SSNMQTTCLIENT.client:loop(0,5)
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
  
    SSNMQTTCLIENT = ssnmqtt:new(nil, CONF.ssn.ACCOUNT, CONF.app.MQTT_HOST, CONF.app.MQTT_PORT, CONF.app.MQTT_BROKER_CLIENT_ID)
    if (SSNMQTTCLIENT) then
        logger:info("MQTT client created successefully")
        SSNMQTTCLIENT.client:login_set(CONF.app.MQTT_BROKER_USER, CONF.app.MQTT_BROKER_PASS)
    
        SSNMQTTCLIENT:setCallBackOnConnect (ssnOnConnect)
        SSNMQTTCLIENT:setCallBackOnMessage (ssnOnMessage)
        SSNMQTTCLIENT:connect()
    else 
        logger:error("MQTT client not created!")
    end

    mainLoop(localLoop())
  end
  
main()
