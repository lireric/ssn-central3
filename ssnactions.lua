require "ssnconf"
require "table"
--require "socket"
--require "ssnUtils"


-- e = getfenv()

local logger
if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end

-- Meta class device:
ssndevices = {
    dev_id = nil,
    channel = 0,
    current_value = nil
}

-- Meta class actions:
ssnactions = {
    act_array = {},
    dev_array = {},
    deviceGetValueCallback = nil,
    deviceSetValueCallback = nil,
    account = 0
}

-- Parse string with action formula (e.g. 'd(1,2) * d("qqq", 0) + d(12,5)')
-- and return table: (dev, channel)
--
function parseActionString(s)
    local w = {}
    for dev, ch in string.gfind(s, "d%(\"*(%w+)\"*%s*,%s*(%w+)%)") do 
        logger:debug ("parseActionString: (%s, %s)",tostring(dev), tostring(ch));
        table.insert(w, {dev, tonumber(ch, 10)})
    end
    return w
end

function ssnactions:fillActions (actions)
    for i,v in ipairs(actions) do
        self:addAction(v.id, v.expression, v.act)
    end
end

function ssnactions:new (o, account, deviceGetValueCallback, deviceSetValueCallback, actions)
    logger:debug ("Creating new ssnactions instanse: account=%d", account)
     o = o or {}
     setmetatable(o, self)
     self.__index = self
     self.account = account
     self.deviceGetValueCallback = deviceGetValueCallback
     self.deviceSetValueCallback = deviceSetValueCallback

    local function d(dev, channel)
        return self:deviceGetValue(dev, channel)
    end
    self.d = d

     -- get parameters from config and fill local array:
    if (actions) then
        for i,v in ipairs(actions) do
            self:addAction(v.id, v.expression, v.act)
        end
    end

     return o
  end

function ssnactions:deviceGetValue(dev, channel)
    local res = nil
    logger:debug ("deviceGetValue: dev=%s, channel = %s", dev, tostring(channel))
    -- TO DO: get last value from DB or cache...
    if (self.deviceGetValueCallback) then
        res = self.deviceGetValueCallback(dev, channel)
    end
    return res
end

function ssnactions:deviceSetValue(dev, channel, value, action_id)
    logger:debug ("deviceSetValue: dev=%s,  channel = %d, value = %s, action_id = %d", dev, channel, tostring(value), action_id)
    if (self.deviceSetValueCallback) then
        self.deviceSetValueCallback(dev, channel, value, action_id)
    end
end

-- scan all actions with this device and check for triggering on given value:
--
function ssnactions:deviceProcessValue(dev, channel, value)
    logger:debug ("deviceGetValue: dev=%s,  channel = %s", dev, channel)
    -- TO DO: get last value from DB or cache...
end

-- add Action to actions array. Action is callback function and must return boolean value (true, if trigger event)
--
function ssnactions:addAction(id, expression, actions)
    logger:info ("addAction: id=%s", id)
    d = self.d
    -- fill actions results array:
    local act_results_array = {}
    for i, cur_act in ipairs(actions) do
        -- select actioned devices (left part of act expression) and result expression:
        local act_dev_str, act_result = string.match(cur_act, "(.+)=(.+)")
        logger:debug ("act_dev_str: %s, act_result: %s", tostring(act_dev_str), tostring(act_result))
        local func, err = pcall(loadstring("return " .. tostring(act_result), "act_result_fn" ))
        if (not func) then
            logger:error ("act_result expression error: %s [%s]", err, act_result)
        end
        act_results_array[i] = {act_dev_array=parseActionString(act_dev_str), act_result_fn = func}
    end

    local func, err = pcall(loadstring("return " .. tostring(expression), "act_expression_fn" ))
    if (not func) then
        logger:error ("act_expression error: %s [%s]", err, expression)
    end
    table.insert(self.act_array, {id=id, expression=func, 
        actions=actions, dev_cache=parseActionString(expression), act_results_array=act_results_array})
    -- self.act_array[id] = action
    logger:info ("Actions: %d", #self.act_array)
end

-- ----------------------- APPLY ACTIONS EXPRESSION AND EXECUTE RESULT EXPRESSIONS IF result = True:
-- input: list of actions (if nil, than call actions)
--
function ssnactions:applyActions(act_list)
    logger:debug ("applyActions")
    if (not act_list) then
        logger:debug ("empty act_list -> return without actions")
        return
    end
    
    d = self.d

    -- function d(dev, channel)
    --     return self:deviceGetValue(dev, channel)
    -- end
    
    for i, cur_action in ipairs(act_list) do
        logger:debug ("Action: id =%s", cur_action.id)
        logger:debug ("num actions: %d", #cur_action.actions)
        logger:debug ("devices cache size: %d", #cur_action.dev_cache)
        local res, err = pcall(cur_action.expression())
        if (err) then
            logger:info ("action [%s] expression return error: %s", cur_action.id, err)
        end
        logger:debug ("cur_action result = %s", tostring(res))
        if (res) then
            logger:info ("fire action!")
            for j, fire_act in ipairs(cur_action.act_results_array) do
                local fn_result, err = pcall(tostring(fire_act.act_result_fn())) -- TO DO: check types..
                if (err) then
                    logger:info ("action [%s] fire_act return error: %s", cur_action.id, err)
                end
                logger:debug ("fire_act [%d]: devs cnt = %d, fn=%s", j, #fire_act.act_dev_array, fn_result)
                for k, fire_dev in ipairs(fire_act.act_dev_array) do
                    logger:debug ("fire_act [%d][%d]: dev[%s, %d] = %s", j, k, fire_dev[1], fire_dev[2], fn_result)
                    self:deviceSetValue(fire_dev[1], fire_dev[2], fn_result, cur_action.id)
                end
            end
        end
    end
end

function ssnactions:getDevActions(dev, channel)
    logger:debug ("getDevActions: dev=%s, channel=%d", dev, channel)
    local tmpActionList = {}
    for i, cur_action in ipairs(self.act_array) do
        logger:debug ("check Action[%d]", cur_action.id)
        if (cur_action.dev_cache) then
            for j, cur_dev in ipairs(cur_action.dev_cache) do
                logger:debug ("cur_action: dev=%s, ch=%d", cur_dev[1], cur_dev[2])
                if ((cur_dev[1] == dev) and (cur_dev[2] == channel)) then
                    logger:debug ("exist!!")
                    table.insert(tmpActionList, cur_action)
                end
            end
        end
    end
    return tmpActionList
end

-- -----------------------------------------------------------------------------------------------------------------
-- for standalone testing only:

local function main()
    local CONF
    print(_VERSION)
    logger:warn ("This func run only for testing purposes!")
    logger:debug ("t0=%.5f", socket.gettime())
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
        logger:error("Error configuration loading. Stop module ssnactions")
        return
    end

    logger:info(string.format("ssnactions module -- [Application name: %s]", CONF.app.name))

-- Test callback functions:
    local function testGetDV(dev, channel)
        logger:debug ("*** testGetDV: dev=%s, channel=%d", dev, channel)
        return 123
    end
    local function testSetDV(dev, channel, value, action_id)
        logger:debug ("*** testSetDV: dev=%s, channel=%d, value=%s", dev, channel, tostring(value))
    end

    local my_ssnactions = ssnactions:new(nil, CONF.ssn.ACCOUNT, testGetDV, testSetDV, CONF.actions)

    -- s = '(d(1,2) * d("qqq", 0) + d(12,5)) >= d(3,0)'
    -- function test_action1()
    --     local res = true
    --     local f = assert(loadstring("return " .. s))
    --     f()
    --     return res
    -- end

    -- logger:debug ("t=%.5f", socket.gettime())
    -- my_ssnactions:addAction("test1", test_action1)
    -- logger:debug ("t=%.5f", socket.gettime())


    local t = my_ssnactions:getDevActions("12", 5)
    print (t, #t)
    for i,v in ipairs(t) do print(i,v) end

    my_ssnactions:applyActions(t)
    logger:debug ("t=%.5f", socket.gettime())


end
  
--main()