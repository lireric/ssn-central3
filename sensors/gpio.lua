-- interface to GPIO provided functions by linux libgpiod CLI (https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/):
-- gpioget    - read values of specified GPIO lines
-- gpioset    - set values of specified GPIO lines, potentially keep the lines

local logger
if LOGGERGLOBAL then
  logger = LOGGERGLOBAL
else
  require "logging.console"
  logger = logging.console()
end
local wd_id
local ssnmqttClient
local CONF
local last_vals = {}
local last_ts
local hart_beat_timeout = 300 -- max interval before pushing nonchanged device value (may be overrided in config)

require "ssnUtils"
require "string"
SOCKET = require("socket")
require "ssnmqtt"
require "ssnconf"

function gpioset(device, pin, value)
    os.execute("gpioset "..device.." "..pin.."="..value)
end

function gpioget(device, pin)
    local command = "gpioget "..device.." "..pin
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return tonumber(string.sub(result, 1, -2), 10)
end

local function gpioOnConnect(success, rc, str)
    logger:info("MQTT connected: %s, %d, %s", tostring(success), rc, str)
    if not success then
      logger:error("Failed to connect: %d : %s\n", rc, str)
      return
    end
    -- subscribe only to ours GPIO topics: 
    ssnmqttClient.client:subscribe("/ssn/acc/"..tostring(ssnmqttClient.account).."/obj/"..tostring(CONF.sensors.obj).."/device/+/+/in", 0)
  end

local function gpioOnMessage(mid, topic, payload)
    logger:debug("MQTT message. Topic=%s : %s", topic, payload)
    local acc
    local rootToken
    local subTokensArray
    acc, rootToken, subTokensArray = parseTopic(topic)
    -- Check destination account:
    if (acc == ssnmqttClient.account) then
        local topic_map = parseTokenArray(rootToken, subTokensArray)
        if (topic_map) then
            if (rootToken == "obj" and topic_map.subToken == "device" and topic_map.action == "in") then
                logger:info("topic_map rootToken: %s, subToken: %s, device: %s, channel: %d, action: %s", topic_map.rootToken, topic_map.subToken, topic_map.device, topic_map.channel, topic_map.action)
                -- Get dev metadata from config:
                local dev_info = get_gpio_dev_info(CONF.sensors.gpio, topic_map.device)
                if (dev_info) then
                    logger:debug("dev_info found")
                    gpioset(dev_info.gpiochip, dev_info.number, payload)
                else
                    logger:warning("dev_info not found!")
                end
            end
        else
            logger:error("Error parsing topic!")
        end
    end
end

local function scanGPIOPoits (co)
--    logger:debug("Scan all GPIO IN ports")
    for i,v in ipairs(CONF.sensors.gpio.pins) do
        if (v.type == "in") then
            local dev_val = gpioget(v.gpiochip, v.number)
            -- check last value and last timestamp:
            local prev_val = last_vals[v.id]
            if (dev_val) then
                if ((not prev_val or (prev_val ~= dev_val) or ((os.time() - last_ts) >= hart_beat_timeout))) then
                    last_ts = os.time()
                    last_vals[v.id] = dev_val
                    ssnmqttClient:publishSensorValue(CONF.sensors.obj, v.id, 0, dev_val, nil, nil)
                end
            else
                logging:warn("gpioget return nil value [%s]", v.id)
            end
        end
    end

    sleep(CONF.sensors.gpio.scan_rate)
    return true
end

-- ****************************************************************** LOOPS:
local function mainLoop (co)
    while true do
--        logger:debug("mainLoop")
        if (ssnmqttClient) then
            ssnmqttClient.client:loop(0,5)
            sleep(0.3)
        end
        local res = scanGPIOPoits(co)
    end
  end

-- ******************************* local loop:
local function localLoop()
    logger:debug("Create GPIO loop coroutine")
    return coroutine.create(function ()
        while true do
            coroutine.yield(nil, nil)
        end
    end)
  end

-- ==================================================================
local function main()

    -- process command line arguments:
    local opts = getopt( arg, "lc" )

    if (opts.l) then
        LOGLEVEL = get_log_level_from_str(opts.l)
        logger:setLevel(LOGLEVEL)
    end

    local file_conf_name = "ssn_conf.yaml"
    if (opts.c) then
        file_conf_name = opts.c
    end
    logger:info("Using config file: %s", file_conf_name)

    CONF = loadSSNConf(file_conf_name)
    if (not CONF) then
        logger:error("Error configuration loading")
        return
    end

    -- override hart_beat_timeout
    if (CONF.sensors.gpio.hart_beat_timeout) then
        hart_beat_timeout = CONF.sensors.gpio.hart_beat_timeout
    end
    -- init last ts:
    last_ts = os.time() - hart_beat_timeout - 1

    ssnmqttClient = ssnmqtt:new(nil, CONF.ssn.ACCOUNT, CONF.app.MQTT_HOST, CONF.app.MQTT_PORT, CONF.app.MQTT_BROKER_CLIENT_ID.."gpio")
    if (ssnmqttClient) then
        logger:info("MQTT client created successefully")
        ssnmqttClient.client:login_set(CONF.app.MQTT_BROKER_USER, CONF.app.MQTT_BROKER_PASS)
    
        ssnmqttClient:setCallBackOnConnect (gpioOnConnect)
        ssnmqttClient:setCallBackOnMessage (gpioOnMessage)
        ssnmqttClient:connect()
    else 
        logger:error("MQTT client not created!")
    end

    mainLoop(localLoop())

end

logger:info ("Hello GPIO!!!")
main()
