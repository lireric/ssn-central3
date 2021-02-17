require "ssnconf"
require "table"
require "socket"
require "ssnUtils"

local CONF

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
    account = 0
}

function d(dev, channel)
    return deviceGetValue(dev, channel)
end

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


function ssnactions:new (o, account)
    logger:debug ("Creating new ssnactions instanse: account=%d", account)
     o = o or {}
     setmetatable(o, self)
     self.__index = self
     self.account = account

     -- TO DO: fill actions array (from config or hardcode?..)
     -- TO DO: fill devices array (cache - ?)
     return o
  end

function deviceGetValue(dev, channel)
    local res = 0
    logger:debug ("deviceGetValue: dev=%s,  channel = %s", dev, channel)
    -- TO DO: get last value from DB or cache...
    return res
end

function deviceSetValue(dev, channel, value)
    logger:debug ("deviceGetValue: dev=%s,  channel = %s, value = %d", dev, channel, value)
    -- TO DO: send value to broker...
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
    -- fill actions results array:
    local act_results_array = {}
    for i, cur_act in ipairs(actions) do
        -- select actioned devices (left part of act expression) and result expression:
        local act_dev_str, act_result = string.match(cur_act, "(.+)=(.+)")
        act_results_array[i] = {act_dev_array=parseActionString(act_dev_str), act_result_fn = assert(loadstring("return " .. act_result))}
    end
    table.insert(self.act_array, {id=id, expression=assert(loadstring("return " .. expression)), 
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
    for i, cur_action in ipairs(act_list) do
        logger:debug ("Action: id =%s", cur_action.id)
        logger:debug ("num actions: %d", #cur_action.actions)
        logger:debug ("devices cache size: %d", #cur_action.dev_cache)
        local res = cur_action.expression()
        logger:debug ("cur_action result = %s", tostring(res))
        if (res) then
            logger:info ("fire action!")
            for j, fire_act in ipairs(cur_action.act_results_array) do
                local fn_result = tostring(fire_act.act_result_fn()) -- TO DO: check types..
                logger:debug ("fire_act [%d]: devs cnt = %d, fn=%s", j, #fire_act.act_dev_array, fn_result)
                for k, fire_dev in ipairs(fire_act.act_dev_array) do
                    logger:debug ("fire_act [%d][%d]: dev[%s, %d] = %s", j, k, fire_dev[1], fire_dev[2], fn_result)
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
-- for standalone testing

local function main()

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

    local my_ssnactions = ssnactions:new(nil, CONF.ssn.ACCOUNT)

    -- get parameters from config and fill local array:
    for i,v in ipairs(CONF.actions) do
        my_ssnactions:addAction(v.id, v.expression, v.act)
    end

    -- local my_ssnactions = ssnactions:new(nil, 2)
    -- local s = 'd(1,2) * d("qqq", 0) + d(12,5)'

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
  
main()