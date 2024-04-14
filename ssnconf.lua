-- load SSN configuration file in yaml format

--local yaml = require('yaml')
local yaml = require('tinyyaml')

local logger

if LOGGERGLOBAL then
    logger = LOGGERGLOBAL
else
    require "logging.console"
    logger = logging.console()
end

local function read_file(path)
    file = io.open(path, "r") -- r read mode and b binary mode
    if not file then
        return nil
    end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

function loadSSNConf(file_name)
    local fileConfName
    if (file_name) then
        fileConfName = file_name
    else
        fileConfName = "ssn_conf.yaml"
    end

    logger:info("load config from %s", fileConfName)

    local fileConfigData = read_file(fileConfName)

    if not fileConfigData then
        logger:error("can't open configuration file '%s'\n", fileConfName)
        return;
    end

    logger:debug("config:\n%s", fileConfigData)
    --  local ssnConf = yaml.load(fileConfigData)
    return yaml.parse(fileConfigData) -- yaml.eval(fileConfigData)
end
