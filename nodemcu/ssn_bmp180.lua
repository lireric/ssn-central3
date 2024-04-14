-- bmp180 pressure and temperature module
-- CONF section example:
-- {bmp180 =
-- {
-- id = "pressure-1",
-- period = 55000, -- timer (ms)
-- pin_sda = 1,    -- i2c sda pin
-- pin_scl = 4,    -- i2c ssl pin
-- oss = 2         -- oversampling setting (0-3)
-- }
-- }
local modname = ...
local oss
local sda, scl
local init_state = false
local dev_id = CONF.sensors.bmp180.id
local dev_obj = CONF.sensors.obj

local function m_init()
    oss = CONF.sensors.bmp180.oss -- oversampling setting (0-3)
    sda, scl = CONF.sensors.bmp180.pin_sda, CONF.sensors.bmp180.pin_scl
    if i2c then
        local bmp180 = require("bmp180")
        bmp180.init(sda, scl)
        init_state = true -- TO DO: check state
    end
end

-- callback for setting values to module
local function bmp180_callback_set()
    -- nothing to do
end

local function bmp180_callback()
   logger:info("timer BMP")

   bmp180.read(oss)
   local t = bmp180.getTemperature()
   local p = bmp180.getPressure()
   -- temperature in degrees Celsius  and Farenheit
   logger:info("Temperature: "..(t/10).." deg C")
   logger:info("Pressure: "..(p * 75 / 10000).." mmHg")

   if CLIENT_PUB then
     CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..dev_obj.."/device/"..dev_id.."/0/out", (t/10), 0, 0, function(client) logger:debug("sent bmp180 temperature") end)
     CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..dev_obj.."/device/"..dev_id.."/1/out", (p * 75 / 10000), 0, 0, function(client) logger:debug("sent bmp180 press") end)
   end
end

local ssn_meta = {
    id = dev_id,
    period = CONF.sensors.bmp180.period,
    callback = bmp180_callback,
    callback_set = bmp180_callback_set,
    init = init_state
}


local M = { ssn_meta = ssn_meta }

-- init module
function M.init()
    m_init()
end

-- get ssn module metadata
function M.getMeta()
    return ssn_meta
end

M[ssn_meta] = ssn_meta
_G[modname or 'ssn_bmp180'] = M

return M