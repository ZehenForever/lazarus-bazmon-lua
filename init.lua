--[[

BazMonitor - Maintains an ini file that is used to monitor current bazaar values

--]]
local mq = require('mq')
local Write = require('lib/Write')
local ini = require('lib/inifile')
local util = require('lib/util')

-- Time in ms to wait for things like windows opening
local WaitTime = 750

-- Default Write output to 'info' messages
-- Override via /collect debug
Write.loglevel = 'info'

local config_file = mq.TLO.MacroQuest.Path() .. '\\config\\BazMonitor.ini'
local results_file = mq.TLO.MacroQuest.Path() .. '\\config\\BazResults.csv'

-- An example config for items that you want monitored
-- We'll use this to write out an example config file if one does not exist
local example_config = {
    ['General'] = {},
    ['Monitor'] = {
        ['Fabled Earthshaker'] = '50000/Compare|<',
        ['Whirligig Flyer Control Device'] = '100000/Compare|<',
    },
    ['Queries'] = {},
}

-- saves our settings to the config file
local save_settings = function (table)
    ini.save(config_file, table)
end

-- Settings originally set to the example
local settings = example_config

-- Parse the settings for an item
local parse_item = function(item)
    local value, compare = string.match(settings['Query'][item], '(%d+)(.*)')
    local comparator = string.match(compare, '([<>=]+)')
    return value, comparator
end

local bazmonitor = function(...)
    local args = {...}

    -- Debug args
    for i,arg in ipairs(args) do
        Write.Debug('/bazmon arg[%d]: %s', i, arg)
    end

    if args[1] == nil then
        Write.Info('BazMon Usage:')
        Write.Info('/bazmon add "<item>" "<value>" "<compare>"')
        Write.Info('/bazmon get "<item>"')
        Write.Info('/bazmon search "<item>"')
    end

    -- Allow verbose output
    if args[1] == 'debug' then
        Write.loglevel = 'debug'
    end

    -- Add an item to monitor
    if args[1] == 'add' then
        if args[2] and args[3] and args[4] then
            if not settings[args[2]] then
                settings[args[2]] = {}
            end
            settings[args[2]][args[3]] = args[4]
            save_settings(settings)
        end
    end

    -- Print setting value for an item
    if args[1] == 'get' then
        if args[2] then
            Write.Info('Setting for %s: %s', args[2], settings['Query'][args[2]])
        end
    end

    -- Parse the item 
    if args[1] == 'parse' then
        if args[2] then
            Write.Info('Setting for %s: %s', args[2], settings['Query'][args[2]])
            if settings['Query'][args[2]] then
                local value, compare = parse_item(args[2])
                Write.Info('Value: %s, Compare: %s', value, compare)
            end
        end
    end

    -- Search the bazaar for an item
    if args[1] == 'search' then
        if args[2] then
            Write.Debug('Searching for %s', args[2])
            settings['Queries'][util.random_string(16)] = string.format("/name|%s", args[2])
            save_settings(settings)
        end
    end

end

-- Load the settings from the config file
-- If the file does not exist, write out an example config file that the user can edit
if util.file_exists(config_file) then
    Write.Info('Config file exists: %s', config_file)
    settings = ini.parse(config_file)
else
    Write.Info('Config file does NOT exist: %s', config_file)
    Write.Info('Writing example config to %s', config_file)
    save_settings(example_config)
    settings = example_config
end

mq.bind('/bazmon', bazmonitor)

Write.Debug('Using BazMonitor config file: %s', config_file)

-- Loop and yield on every frame
while true do
    mq.doevents()
    mq.delay(1)
end