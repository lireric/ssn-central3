-- Main program unit
-- From here starting all other modules from config
-- 2020 - Ernold Vasilyev ericv@mail.ru

require "logging.console"
require "ssnmqtt"
require "ssnconf"
require "ssnUtils"
local ltn12 = require "ltn12"
--local yaml = require('yaml')
local yaml = require('tinyyaml')

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
local function mainLoop (co)
    while true do
--        logger:debug("Start MQTT consumer")
        if (SSNMQTTCLIENT) then
            SSNMQTTCLIENT.client:loop(0,5)
            sleep(10.3)
        end
        sleep(10.3)
    end
  end

-- ******************************* local loop:
local function localLoop()
    logger:debug("Create local Loop coroutine")
    return coroutine.create(function ()
        sleep(10.3)
        coroutine.yield(nil, nil)
    end)
  end

-- ==================================================================
local function main()

    logger:info("Starting SSN")

    -- process command line arguments:
    local opts = getopt( arg, "ldc" )
    if (opts.l) then
        -- LOGLEVEL = get_log_level_from_str(opts.l)
        LOGLEVEL = opts.l
        logger:info("set log level from command args: %s", opts.l)
    end

    logger:info("Loglevel=%s", LOGLEVEL)
  
    LOGGERGLOBAL:setLevel(LOGLEVEL)
  
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
    logger:info("Application name: %s, account: %d", CONF.app.name, CONF.ssn.ACCOUNT)
    logger:info("Starting modules ...")

    logger:info("persist=%s", CONF.persist.start)

    if (CONF.persist and CONF.persist.start == 1) then
        -- Start DB storing module
        logger:info("Start DB storing module")
        os.execute("lua mqttPersist.lua -c "..file_conf_name) -- > /dev/null &")
    end
    if (CONF.bot and CONF.bot.start == 1) then
        -- Start telegram bot module
        logger:info("Start telegram bot module")
    end
    if (CONF.sensors and CONF.sensors.gpio) then
        -- Start GPIO IN monitoring
        logger:info("Start GPIO monitoring")
        os.execute("lua sensors/gpio.lua -c "..file_conf_name.."> /dev/null &")
    end
    if (CONF.sensors and CONF.sensors.ds18b20) then
        -- Start ds18b20 monitoring
        logger:info("Start ds18b20 monitoring")
        for i,v in ipairs(CONF.sensors.ds18b20.masters) do
            logger:info("Start monitoring ds18b20 master path: %s", v.path)
            os.execute("lua sensors/18b20.lua -i "..v.path.." -c "..file_conf_name.."> /dev/null &")
        end
    end
    if (CONF.sensors and CONF.sensors.watchdog_tcp) then
        -- Start all network resourses monitoring
        logger:info("Start all network resourses monitoring")
        for i,v in ipairs(CONF.sensors.watchdog_tcp.destinations) do
            logger:info("Start monitoring watchdog ID: %s", v.id)
            os.execute("lua sensors/watchdog_tcp.lua -i "..v.id.." -c "..file_conf_name.."> /dev/null &")
        end
    
        --logger:info(ret)
    end
  

    mainLoop(localLoop())
  end
  
main()
