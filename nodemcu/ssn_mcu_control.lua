-- main control module
LOGLEVEL = CONF.app.LOGLEVEL
require "ssnmqttutils"

ACC = CONF.ssn.ACCOUNT -- current account
OBJ = CONF.sensors.obj -- current object

logger:info("Start SSN application %s, account=%d, object=%d", CONF.app.name, ACC, OBJ)

MQTTBROKERADDR=CONF.app.MQTT_HOST
MQTTBROKERPORT=CONF.app.MQTT_PORT
MQTTCLIENT=CONF.app.MQTT_BROKER_CLIENT_ID
MQTTUSER=CONF.app.MQTT_BROKER_USER
MQTTPASSW=CONF.app.MQTT_BROKER_PASS

CLIENT_PUB = nil
SSN_DEV_META_ARRAY = {} -- map of the successfully initialized modules: {dev_id: {period, callback, callback_set, init_state}}
--DEVICE_TYPE_MAP = fillDeviceTypesMap(CONF.sensors)

function ssn_mcu_main()
    logger:info("Starting modules ...")

    if (CONF.sensors and CONF.sensors.bmp180) then
        -- Start bmp180 monitoring
        logger:info("Start bmp180 monitoring")
        local ssn_bmp180 = require("ssn_bmp180")
        ssn_bmp180.init()
        local meta = ssn_bmp180.getMeta()
        if meta and ssn_bmp180.init then
            SSN_DEV_META_ARRAY[ssn_bmp180.id] = ssn_bmp180
            logger:debug("module ssn_bmp180 added")
        end
    end
    if (CONF.sensors and CONF.sensors.bme280) then
        -- Start bmp280 monitoring
        logger:info("Start bme280 monitoring")
        local ssn_bme280 = require("ssn_bme280")
        ssn_bme280.init()
        local meta = ssn_bme280.getMeta()
        if meta and meta.init then
            SSN_DEV_META_ARRAY[meta.id] = meta
            logger:debug("module ssn_bme280 added")
        end
    end
    if (CONF.sensors and CONF.sensors.gpio) then
        -- Start GPIO IN monitoring
        logger:info("Start GPIO monitoring")
        local ssn_gpio = require("ssn_gpio")
        ssn_gpio.init()
        local meta = ssn_gpio.getMeta()
        if meta and meta.init then
            SSN_DEV_META_ARRAY[meta.id] = meta
            logger:info("module gpio added")
        else
            logger:error("module gpio not initialized")
        end
    end
    if (CONF.sensors and CONF.sensors.ds18b20) then
        -- Start ds18b20 monitoring
        logger:info("Start ds18b20 monitoring")
        -- for i,v in ipairs(CONF.sensors.ds18b20.masters) do
        --     logger:info("Start monitoring ds18b20 master path: %s", v.path)
        -- end
    end
    if (CONF.sensors and CONF.sensors.watchdog_tcp) then
        -- Start all network resourses monitoring
        logger:info("Start all network resourses monitoring")
        -- for i,v in ipairs(CONF.sensors.watchdog_tcp.destinations) do
        --     logger:info("Start monitoring watchdog ID: %s", v.id)
        -- end

        --logger:info(ret)
    end
end
---------------------------------

-- init mqtt client with logins, keepalive timer 120sec
m = mqtt.Client(MQTTCLIENT, 120, MQTTUSER, MQTTPASSW)

-- setup Last Will and Testament (optional)
-- Broker will publish a message with qos = 0, retain = 0, data = "offline"
-- to topic "/lwt" if client don't send keepalive packet
m:lwt("/lwt", "offline", 0, 0)

m:on("offline", function(client) print ("offline") node.restart() end)

-- on publish message receive event
m:on("message", function(client, topic, data)
    logger:debug(topic .. ":" )

    if data ~= nil then
        logger:debug("data=%s",data)
        local account, token, subtokens = parseTopic(topic)
        logger:debug ("acc=%d token=%s subtokens=%s",account, token, unpack(subtokens))
        -- check account
        if account == ACC then
            local ss = parseTokenArray(token, subtokens)
            -- check object
            if ss and ss["obj"] == OBJ then
                logger:debug ("obj=%d device=%s ch=%s", ss["obj"], ss["device"], ss["channel"])
                local cur_dev_meta = SSN_DEV_META_ARRAY[ss["device"]]
                if cur_dev_meta then
                    local ch = tonumber(ss["channel"])
                    -- call function for setting module values
                    cur_dev_meta.callback_set(ss["channel"], data)
                else
                    logger:error("absent meta for device!")
                end

            end
        end
    end
end)

-- on publish overflow receive event
m:on("overflow", function(client, topic, data)
    logger:info (topic .. " partial overflowed message: " .. data )
end)

-- for TLS: m:connect("192.168.11.118", secure-port, 1)
m:connect(MQTTBROKERADDR, MQTTBROKERPORT, false, function(client)
    logger:info("connected")
    CLIENT_PUB = client

    -- register timers for all modules
    for k,v in pairs(SSN_DEV_META_ARRAY) do
        local period = v.period
        if period and period > 0 then
            logger:info("registering timer for %s, period=%d (ms)", k, period)
            tmr.create():alarm(period, tmr.ALARM_AUTO, v.callback)
        end
    end

  -- Calling subscribe/publish only makes sense once the connection
  -- was successfully established. You can do that either here in the
  -- 'connect' callback or you need to otherwise make sure the
  -- connection was established (e.g. tracking connection status or in
  -- m:on("connect", function)).

  -- subscribe topic with qos = 0 for all devices
  client:subscribe("/ssn/acc/"..ACC.."/obj/"..OBJ.."/device/+/+/in", 0, function(client) print("subscribe success") end)
  
  --   client:subscribe("/ssn/acc/3/obj/147/device/+/+/in", 0, function(client) print("subscribe success") end)
  -- publish a message with data = hello, QoS = 0, retain = 0
  -- client:publish("/ssn/acc/3/obj/147/device/1/1/out", "45.6", 0, 0, function(client) print("sent") end)
end,
function(client, reason)
  print("Connection failed reason: " .. reason)
end)

m:close()
-- you can call m:connect again after the offline callback fires

--main()
