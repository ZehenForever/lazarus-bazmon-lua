--[[

BazMonitor - Maintains an ini file that is used to monitor current bazaar values

]]
local mq = require('mq')
local Write = require('lib/Write')
local ini = require('lib/inifile')
local util = require('lib/util')
local ftcsv = require('lib/ftcsv')
local imgui = require('ImGui')

local open_gui = true

-- Time in seconds to wait for the bazaar to respond
local bazaar_wait = 5

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

-- convenience function to trim whitespace from a string
local trim_space = function(s)
    --return (s:gsub("^%s*(.-)%s*$", "%1"))
    return s:match( "^%s*(.-)%s*$" )
end

-- Settings originally set to the example
local settings = example_config

-- Parse the settings for an item
local parse_item = function(item)
    local value, compare = string.match(settings['Query'][item], '(%d+)(.*)')
    local comparator = string.match(compare, '([<>=]+)')
    return value, comparator
end

local current_query_id = "uu5r0zq6zbz4kkv5"
local start_search = false
local start_save_settings = false
local currently_searching = false
local search_results = {}

-- Searches the CSV results file for a queryID
-- Waits for a configured number of seconds for the results to be written to the file
local load_search_results = function(queryID)
    Write.Debug('Reading CSV file: %s', results_file)

    currently_searching = true

    -- Reset the search results
    search_results = {}

    -- loop until time is up, waiting for the results to be written to the file
    local found_item = false
    for i=1,bazaar_wait do
        mq.delay(1000)
        Write.Debug('Reading CSV file: %s', results_file)
        for index, result in ftcsv.parseLine(results_file, ",") do
            if result.QueryID == queryID then
                found_item = true
                Write.Debug('Result[%d]: %s "%s" %s %s', index, result.QueryID, result.Item, result.Price, result.Seller)
                search_results[#search_results+1] = result
            end
        end
        if found_item then
            break
        end
    end

    currently_searching = false
end

local search_item_name = ""

local render_ui = function(open)
    local main_viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20, ImGuiCond.FirstUseEver)

    -- change the window size
    imgui.SetNextWindowSize(600, 300, ImGuiCond.FirstUseEver)

    local open, show = imgui.Begin("BazMonitor", true)

    if not show then
        ImGui.End()
        return open
    end

    ImGui.PushItemWidth(ImGui.GetFontSize() * -12)

    -- Beginning of window elements
    imgui.Text("Bazaar Search")

    -- Item name search input box
    search_item_name, _ = imgui.InputText("Item Name", search_item_name, ImGuiInputTextFlags.EnterReturnsTrue)

    -- Search button
    if ImGui.Button("Search") then
        -- What you want the button to do
        search_item_name = trim_space(search_item_name)
        Write.Debug('Searching for "%s"', search_item_name)

        -- Add the search to our INI file
        local query_id = util.random_string(16)

        -- Clear the queries, keep it a single query for now
        settings['Queries'] = {} 
        settings['Queries'][query_id] = string.format("/name|%s", search_item_name)

        -- Set the current query ID to the one we just created
        current_query_id = query_id

        -- Signal that we want to save the settings to the INI file
        -- Saving our INI file will trigger the external script to query the bazaar
        start_save_settings = true

        -- Signal that we want to start searching for the results
        -- This will poll the results file for the queryID
        start_search = true
    end
    ImGui.Separator()

    if currently_searching then
        imgui.Text("Searching for %s ...", search_item_name)
        ImGui.Separator()
    else
        imgui.Text("Search Results")

        -- Results table
        if ImGui.BeginTable('BazResults', 4, ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn('QueryID', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Price', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Seller', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableHeadersRow()

            for i, result in ipairs(search_results) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text(result.QueryID)
                ImGui.TableNextColumn()
                ImGui.Text(result.Item)
                ImGui.TableNextColumn()
                ImGui.Text(result.Price)
                ImGui.TableNextColumn()
                ImGui.Text(result.Seller)
            end
            ImGui.EndTable()
        end

    end


    -- End of main window element area --

    -- Required for window elements
    imgui.Spacing()
    imgui.PopItemWidth()
    imgui.End()

    return open
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
            local query_id = util.random_string(16)
            settings['Queries'][query_id] = string.format("/name|%s", args[2])
            save_settings(settings)
            search_results(query_id)
        end
    end

    if args[1] == 'csv' then
        Write.Debug('Reading CSV file: %s', results_file)
        for index, result in ftcsv.parseLine(results_file, ",") do
            Write.Debug('Result[%d]: %s "%s" %s %s', index, result.QueryID, result.Item, result.Price, result.Seller)
        end
    end

    if args[1] == 'ui' then
        Write.Debug('Rendering UI')
        render_ui()
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

ImGui.Register('rend_ui', function()
    open_gui = render_ui(open_gui)
end)

-- Loop and yield on every frame
while open_gui do
    mq.doevents()
    if start_save_settings then
        start_save_settings = false
        save_settings(settings)
    end
    if start_search then
        start_search = false
        load_search_results(current_query_id)
    end
    mq.delay(1)
end
