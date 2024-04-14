-- bmp180 pressure and temperature module
-- CONF section example:
-- gpio =
-- {
--     id = "gpio-mcu1",
--     pins = {
--     {
--         comment = "test-led-1",
--         gpiochip = 0,
--         type = "out"
--     },
--     {
--         comment = "test-button-1",
--         gpiochip = 1,
--         type = "in"
--     }
--     }
-- }

local M = {}
_G["ssn_gpio"] = M

local dev_id = CONF.sensors.gpio.id
local ssn_meta = {
    id = dev_id,
    period = 0, -- use interrupt for input event generation
    init = false
}

local function m_init()
    -- init pins:
    for i,v in ipairs(CONF.sensors.gpio.pins) do
        local pin = v.gpiochip
        logger:debug("%d. pin=%d, type=%s", i, pin, v.type)
        if v.type == "out" then
            gpio.mode(v.gpiochip, gpio.OUTPUT)
        elseif v.type == "int" then
            local pulse1, delta = 0, 0
            gpio.mode(v.gpiochip, gpio.INT)
            local function pin_cb(level, pulse2)
                delta = pulse2 - pulse1 -- TO DO: use delta for switch bounces removing
                logger:debug("gpio int: level=%s, pulse=%d, delta=%d", level, pulse2, delta)
                local v_out = level == gpio.HIGH and 1 or 0
                pulse1 = pulse2
                if CLIENT_PUB then
                    CLIENT_PUB:publish("/ssn/acc/"..ACC.."/obj/"..OBJ.."/device/"..dev_id.."/"..pin.."/out", v_out, 0, 0, function(client) logger:debug("sent gpio") end)
                end
                gpio.trig(pin, level == gpio.HIGH and "down" or "up")
            end
            gpio.trig(pin, "down", pin_cb)
        else
            gpio.mode(v.gpiochip,gpio.INPUT) -- TO DO: make action for manual send to mqtt INPUT state
        end
    end
    ssn_meta.init = true
end


-- callback for setting values to module
local function gpio_callback_set(pin, data)
    if data == "0" then
        gpio.write(pin,gpio.LOW)
    else
        gpio.write(pin,gpio.HIGH)
    end
end

local function gpio_callback()
 -- nothing to do
end

ssn_meta["callback"] = gpio_callback
ssn_meta["callback_set"] = gpio_callback_set

-- init module
function M.init()
    m_init()
end

-- get ssn module metadata
function M.getMeta()
    return ssn_meta
end

return M
