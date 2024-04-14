-- bmp280/bme280 pressure, humidity and temperature module
-- CONF section example:
-- {bmp280 =
-- {
-- id = "pressure-1",
-- period = 55000, -- timer (ms)
-- pin_sda = 8,    -- i2c sda pin
-- pin_scl = 7,    -- i2c ssl pin
-- altitude = 100, -- correction by altitude
-- oss = 2         -- oversampling setting (0-3)
-- }
-- }
local modname = ...
local M = {}
_G[modname or 'ssn_bme280'] = M

local oss
local sda, scl
local dev_id = CONF.sensors.bme280.id
local dev_obj = CONF.sensors.obj
local altitude = CONF.sensors.bme280.altitude
local ssn_meta = {
    id = dev_id,
    period = CONF.sensors.bme280.period,
    init = false
}

local function m_init()
   oss = CONF.sensors.bme280.oss -- oversampling setting (0-3)
   sda, scl = CONF.sensors.bme280.pin_sda, CONF.sensors.bme280.pin_scl
   if i2c then
      require "bme280"
      i2c.setup(0, sda, scl, i2c.SLOW) -- call i2c.setup() only once
      local bme_res = bme280.setup()
      logger:info ("BMEx80 init result: "..bme_res)
      if bme_res then
         ssn_meta.init = true
      end
   end
end

-- callback for setting values to module
local function bme280_callback_set()
    -- nothing to do
end

local function bme280_callback()
   logger:info("timer BME280")

   local T, P, H, QNH = bme280.read(altitude)
--    local Tsgn = (T < 0 and -1 or 1); T = Tsgn*T
   logger:debug("T=%.2f", T/100)
   logger:debug("QFE=%d.%03d", P/1000, P%1000)
   logger:debug("QNH=%d.%03d", QNH/1000, QNH%1000)
   logger:debug("humidity=%d.%03d%%", H/1000, H%1000)

   -- pressure in differents units
   -- print("Pressure: "..(p).." Pa")
   -- print("Pressure: "..(p / 100).."."..(p % 100).." hPa")
   -- print("Pressure: "..(p / 100).."."..(p % 100).." mbar")

   -- logger:info("Pressure: "..(p * 75 / 10000).." mmHg")

   if CLIENT_PUB then
     CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..dev_obj.."/device/"..dev_id.."/0/out", (T/100), 0, 0, function(client) logger:debug("sent bme280 temperature") end)
     CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..dev_obj.."/device/"..dev_id.."/1/out", (QNH * 75 / 100000), 0, 0, function(client) logger:debug("sent bme280 press") end)
     CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..dev_obj.."/device/"..dev_id.."/2/out", (H/1000), 0, 0, function(client) logger:debug("sent bme280 humidity") end)
   end
end

ssn_meta["callback"] = bme280_callback
ssn_meta["callback_set"] = bme280_callback_set

-- init module
function M.init()
    m_init()
end

-- get ssn module metadata
function M.getMeta()
    return ssn_meta
end

return M



