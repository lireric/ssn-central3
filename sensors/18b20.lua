-- interface to reading data from 1-wire device (18b20 sensor)

local logger
if LOGGERGLOBAL then
  logger = LOGGERGLOBAL
else
  require "logging.console"
  logger = logging.console()
end
local master_path
local master_map
local ssnmqttClient
local CONF

require "ssnUtils"
require "string"
SOCKET = require("socket")
require "ssnmqtt"
require "ssnconf"
require "io"

logger:info ("Hello Watchdog!!!")

-- ==================================================================
local function main()

    -- process command line arguments:
    local opts = getopt( arg, "lic" )

-- get master path (-i):
    if (opts.i) then
        master_path = opts.i
    else 
        logger:error("Error: absent master path!")
        return nil 
    end
    logger:info("master path: %s", master_path)

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

    local scan_rate = 60
    -- search master parameters in config:
    for i,v in ipairs(CONF.sensors.ds18b20.masters) do
        if (v.path == master_path) then
            master_map = v
            -- override scan_rate:
            if (v.scan_rate) then
                scan_rate = v.scan_rate
            end
            break
        end
    end

    if (not master_map) then
        logger:error("Error: master path not fount in config!")
        return 0
    end
    local mqtt_client_id = string.gsub(master_path,"/","_")
    ssnmqttClient = ssnmqtt:new(nil, CONF.ssn.ACCOUNT, CONF.app.MQTT_HOST, CONF.app.MQTT_PORT, CONF.app.MQTT_BROKER_CLIENT_ID..mqtt_client_id)
    if (ssnmqttClient) then
        logger:info("MQTT client created successefully")
        ssnmqttClient.client:login_set(CONF.app.MQTT_BROKER_USER, CONF.app.MQTT_BROKER_PASS)
-- TO DO: process change parameters...    
--            ssnmqttClient:setCallBackOnConnect (ssnOnConnect)
--            ssnmqttClient:setCallBackOnMessage (ssnOnMessage)
        ssnmqttClient:connect()
    else 
        logger:error("MQTT client not created!")
    end

-- TO DO: get devices list...
--     --dev_path = "/sys/devices/w1_bus_master1"
-- dev_path = "/home/eric/tmp/1w"
-- a = io.lines("memory.x")
-- for line in a do print (line) end

    while true do
        logger:debug("ds18b20 step")
        for i,dev in ipairs(master_map.devices) do
            -- get data from sysfs:
            logger:debug("dev_id: %s, dev_name: %s", dev.id, dev.name)
            local f = io.open(master_path.."/"..dev.name.."/temperature", "r")
	    local temp_str
            if (f) then
                logger:debug("dev file open")
                temp_str = f:read("*line")
	    else
        	local f = io.open(master_path.."/"..dev.name.."/w1_slave", "r")
                temp_str = f:read("*line") -- TO DO: check crc...
                temp_str = f:read("*line")
		if (temp_str) then
		    local npos = string.find(temp_str, "t=")
		    if (npos) then
			temp_str = string.sub(temp_str, npos+2)
		    end
		end
	    end
                if (temp_str) then
                    logger:debug("temp_str: %s", temp_str)
                    local temp_num = tonumber(temp_str, 10)
		    if (temp_num) then
			temp_num = temp_num / 1000.0 -- convert from t*1000 to real float t
                	ssnmqttClient:publishSensorValue(CONF.sensors.obj, dev.id, 0, temp_num, nil, nil)
		    end
                end
        end
        socket.sleep(scan_rate)
    end
end

main()