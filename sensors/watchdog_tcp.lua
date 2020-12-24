-- network resourses watchdog

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

require "ssnUtils"
require "string"
SOCKET = require("socket")
require "ssnmqtt"
require "ssnconf"

logger:info ("Hello Watchdog!!!")

-- ==================================================================
local function main()

    -- process command line arguments:
    local opts = getopt( arg, "lic" )

-- get Watchdog ID:
    if (opts.i) then
        wd_id = opts.i
    else 
        logger:error("Error: absent watchdog ID!")
        return nil 
    end
    logger:info("Watchdog ID: %s", wd_id)

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

    local address
    local command
    local scan_rate = 60
    -- get parameters from config and generateeee command string:
    for i,v in ipairs(CONF.sensors.watchdog_tcp.destinations) do
        if (v.id == wd_id) then
            address = v.address
            command = v.command
            scan_rate = v.scan_rate
            break
        end
    end

    if (command == "ping") then
        if (not address) then
            logger:error("Error: unknown address!")
            return nil
        end

        command = 'ping -c 4 '..address..' | grep -oP ".*time=\\K\\d+"'
        logger:debug("command: %s", command)

        ssnmqttClient = ssnmqtt:new(nil, CONF.ssn.ACCOUNT, CONF.app.MQTT_HOST, CONF.app.MQTT_PORT, CONF.app.MQTT_BROKER_CLIENT_ID..wd_id)
        if (ssnmqttClient) then
            logger:info("MQTT client created successefully")
            ssnmqttClient.client:login_set(CONF.app.MQTT_BROKER_USER, CONF.app.MQTT_BROKER_PASS)
        
--            SSNMQTTCLIENT:setCallBackOnConnect (ssnOnConnect)
--            SSNMQTTCLIENT:setCallBackOnMessage (ssnOnMessage)
            ssnmqttClient:connect()
        else 
            logger:error("MQTT client not created!")
        end

        while true do
            logger:debug("Watchdog step")
            res = sys_command(command)
            logger:debug("res: %s", res)
            c = 0
            a = 0
            for w in string.gfind(res, "%d+") do
                t = tonumber(w, 10)
                a = a + t
                c = c + 1
                logger:debug("w: %d", t)
            end
            if (c == 0) then
                time_avg = -1
            else
                time_avg = a / c
            end
            logger:info("average response time: %d", time_avg)
            ssnmqttClient:publishSensorValue(CONF.sensors.obj, wd_id, 0, time_avg, nil, nil)
            socket.sleep(scan_rate)
        end
    else
        logger:error("Error: unknown command!")
        return nil
    end
end

main()
