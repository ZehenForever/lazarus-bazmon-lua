--[[

BazMonitor - Maintains an ini file that is used to monitor current bazaar values

]]
local mq = require('mq')
local Write = require('lib/Write')
local ini = require('lib/inifile')
local util = require('lib/util')
local ftcsv = require('lib/ftcsv')
local ImGui = require('ImGui')
local icons = require('mq.icons')

local open_gui = true

-- Time in seconds to wait for the bazaar to respond
local bazaar_wait = 5

-- Default Write output to 'info' messages
-- Override via /bazmon debug
Write.loglevel = 'info'

local config_file = mq.TLO.MacroQuest.Path() .. '\\config\\BazMonitor.ini'
local results_file = mq.TLO.MacroQuest.Path() .. '\\config\\BazResults.csv'

-- An example config for items that you want monitored
-- We'll use this to write out an example config file if one does not exist
local example_config = {
    ['General'] = {
        ['Window Locked'] = false,
    },
    ['Monitor'] = {
        ['Fabled Earthshaker'] = '50000/Price|<',
        ['Whirligig Flyer Control Device'] = '100000/Price|<',
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

-- The list of classes that can are valid search filters
local classes = {
    ["*Any*"] = -1,
    ["Bard"] = 128,
    ["Beastlord"] = 16384,
    ["Berserker"] = 32768,
    ["Cleric"] = 2,
    ["Druid"] = 32,
    ["Enchanter"] = 8192,
    ["Magician"] = 4096,
    ["Monk"] = 64,
    ["Necromancer"] = 1024,
    ["Paladin"] = 4,
    ["Ranger"] = 8,
    ["Rogue"] = 256,
    ["Shadowknight"] = 16,
    ["Shaman"] = 512,
    ["Warrior"] = 1,
    ["Wizard"] = 2048,
}

local races = {
    ["*Any*"] = -1,
    ["Barbarian"] = 2,
    ["Dark Elf"] = 32,
    ["Drakkin"] = 32768,
    ["Dwarf"] = 128,
    ["Erudite"] = 4,
    ["Froglok"] = 16384,
    ["Gnome"] = 2048,
    ["Half Elf"] = 64,
    ["Halfling"] = 1024,
    ["High Elf"] = 16,
    ["Human"] = 1,
    ["Iksar"] = 4096,
    ["Ogre"] = 512,
    ["Troll"] = 256,
    ["Vah Shir"] = 8192,
    ["Wood Elf"] = 8,
}

local slots = {
    ["*Any*"] = -1,
    ["Ammo"] = 2097152,
    ["Waist"] = 1048576,
    ["Feet"] = 524288,
    ["Legs"] = 262144,
    ["Chest"] = 131072,
    ["Fingers"] = 98304,
    ["Finger1"] = 65536,
    ["Finger2"] = 32768,
    ["Secondary"] = 16384,
    ["Primary"] = 8192,
    ["Hands"] = 4096,
    ["Range"] = 2048,
    ["Wrists"] = 1536,
    ["Wrist1"] = 1024,
    ["Wrist2"] = 512,
    ["Back"] = 256,
    ["Arms"] = 128,
    ["Shoulders"] = 64,
    ["Neck"] = 32,
    ["Ears"] = 18,
    ["Ear1"] = 16,
    ["Face"] = 8,
    ["Head"] = 4,
    ["Ear2"] = 2,
    ["Charm"] = 1,
}

local stats = {
    ["*Any*"] = "-1",
    ["Accuracy"] = "accuracy",
    ["Agility"] = "aagi",
    ["Armor Class"] = "ac",
    ["Attack"] = "attack",
    ["Avoidance"] = "avoidance",
    ["Backstab"] = "backstabdmg",
    ["Charisma"] = "acha",
    ["Clairvyoance"] = "clairvoyance",
    ["Cold"] = "cr",
    ["Combat Effects"] = "combateffects",
    ["Corruption"] = "svcorruption",
    ["Damage"] = "damage",
    ["Damage Shield"] = "damageshield",
    ["Delay"] = "delay",
    ["Dexterity"] = "adex",
    ["Disease"] = "dr",
    ["DoT Shielding"] = "dotshielding",
    ["Endurance"] = "endur",
    ["Endurance Regen"] = "enduranceregen",
    ["Fire"] = "fr",
    ["Haste"] = "haste",
    ["Heal Amount"] = "healamt",
    ["Health"] = "hp",
    ["Regen"] = "regen",
    ["Heroic Agility"] = "heroic_agi",
    ["Heroic Charisma"] = "heroic_cha",
    ["Heroic Cold"] = "heroic_cr",
    ["Heroic Dexterity"] = "heroic_dex",
    ["Heroic Disease"] = "heroic_dr",
    ["Heroic Fire"] = "heroic_fr",
    ["Heroic Magic"] = "heroic_mr",
    ["Heroic Intelligence"] = "heroic_int",
    ["Heroic Poison"] = "heroic_pr",
    ["Heroic Stamina"] = "heroic_sta",
    ["Heroic Strength"] = "heroic_str",
    ["Heroic Corruption"] = "heroic_svcorrup",
    ["Heroic Wisdom"] = "heroic_wis",
    ["Intelligence"] = "aint",
    ["Magic"] = "mr",
    ["Mana"] = "mana",
    ["Mana Regen"] = "manaregen",
    ["Poison"] = "pr",
    ["Shielding"] = "shielding",
    ["Spell Damage"] = "spelldmg",
    ["Spell Shielding"] = "spellshield",
    ["Strikethrough"] = "strikethrough",
    ["Stun Resist"] = "stunresist",
    ["Stamina"] = "asta",
    ["Strength"] = "astr",
    ["Wisdom"] = "awis",
}

local aug_types = {
    ["*Any*"] = "2147483647",
    ["1"] = "1",
    ["2"] = "2",
    ["3"] = "4",
    ["4"] = "8",
    ["5"] = "16",
    ["6"] = "32",
    ["7"] = "64",
    ["8"] = "128",
    ["9"] = "256",
    ["10"] = "512",
    ["11"] = "1024",
    ["12"] = "2048",
    ["13"] = "4096",
    ["14"] = "8192",
    ["15"] = "16384",
    ["16"] = "32768",
    ["17"] = "65536",
    ["18"] = "131072",
    ["19"] = "262144",
    ["20"] = "524288",
    ["21"] = "1048576",
    ["22"] = "2097152",
    ["23"] = "4194304",
    ["24"] = "8388608",
    ["25"] = "16777216",
    ["26"] = "33554432",
    ["27"] = "67108864",
    ["28"] = "134217728",
    ["29"] = "268435456",
    ["30"] = "536870912",
}

local item_types = {
    ["*Any*"] = "-1",
    ["1H Blunt"] = "3",
    ["1H Piercing"] = "2",
    ["1H Slashing"] = "0",
    ["2H Blunt"] = "4",
    ["2H Piercing"] = "35",
    ["2H Slashing"] = "1",
    ["Alcohol"] = "38",
    ["Archery"] = "5",
    ["Armor"] = "10",
    ["Arrow"] = "27",
    ["Augmentation"] = "54",
    ["Bandages"] = "18",
    ["Brass Instrument"] = "25",
    ["Charm"] = "52",
    ["Combinable"] = "17",
    ["Compass"] = "40",
    ["Drink"] = "15",
    ["Fishing Bait"] = "37",
    ["Fishing Pole"] = "36",
    ["Food"] = "14",
    ["Gems"] = "11",
    ["Jewelry"] = "29",
    ["Key"] = "33",
    ["Key (bis)"] = "39",
    ["Light"] = "16",
    ["Lockpicks"] = "12",
    ["Martial"] = "45",
    ["Note"] = "32",
    ["Percussion Instrument"] = "26",
    ["Poison"] = "42",
    ["Potion"] = "21",
    ["Scroll"] = "20",
    ["Shield"] = "8",
    ["Stringed Instrument"] = "24",
    ["Throwing"] = "19",
    ["Throwing ranged items"] = "7",
    ["Tome"] = "31",
    ["Wind Instrument"] = "23",
}

local direction = {
    ["Ascending"] = "ASC",
    ["Descending"] = "DESC",
}

-- The master list of all selected search filters
-- These will be used to build the query to be written to the INI file
local search_filter = {}

-- Textbox search filters
local search_item_name = ""
local search_min_price = 0
local search_max_price = 0

-- Dropdown search filters
local filters = {
    ["Class"] = classes,
    ["Race"] = races,
    ["Slot"] = slots,
    ["Stat"] = stats,
    ["Aug"] = aug_types,
    ["Type"] = item_types,
    ["Direction"] = direction,
}

-- Builds out the query to be written to the INI file
local build_query = function()
    local query = ""
    if search_item_name ~= "" then
        query = query .. string.format("/Name|%s", search_item_name)
    end
    if search_min_price > 0 then
        query = query .. string.format("/PriceMin|%d", search_min_price)
    end
    if search_max_price > 0 then
        query = query .. string.format("/PriceMax|%d", search_max_price)
    end
    for key, val in pairs(search_filter) do
        Write.Debug("Writing filter: %s = %s", key, val)
        local value = filters[key][val]
        query = query .. string.format("/%s|%s", key, value)
    end
    return query
end

local current_search_filter = function(filter)
    local indexes = {}
    for i, val in ipairs(search_filter) do
        indexes[val] = i
    end
    if indexes[filter] then
        return indexes[filter]
    end
    return 0
end

-- Add a search filter
local search_filter_add = function(filter, value)
    Write.Debug('Adding filter: %s = %s', filter, value)
    --filter = util.upper_first(filter)
    --value = util.upper_first(value)
    search_filter[filter] = value
end


-- If this search filter has been set, it returns the index of the value from its list of valid values
local search_filter_index = function(filter)
    filter = util.upper_first(filter)
    local value = search_filter[filter]
    if value == nil then
        return 0
    end
    if filters[filter] then
        for i, val in ipairs(filters[filter]) do
            if val == value then
                return i
            end
        end
    else
        Write.Debug('No filter for %s', filter)
        return 0
    end
    return 1234
end

-- Renders a dropdown filter for Bazaar searches
local render_search_dropdown = function(label --[[string]], line_offset --[[int]], order --[[function]])
    if line_offset == nil then line_offset = 0 end
    local windowSize = ImGui.GetWindowWidth()
    local labelPadding = windowSize / 4
    if labelPadding < 85 then labelPadding = 85 end

    label = label
    ImGui.Text(label)
    ImGui.SameLine(line_offset + labelPadding - 20)
    ImGui.PushItemWidth(windowSize / 4)
    local current_val = current_search_filter(label)
    if ImGui.BeginCombo("##"..label, search_filter[label], 0) then

        -- Iterate through the list of valid values for this label
        for k, v in util.spairs(filters[label], order) do

            -- Select the value that matches our current search filter
            local is_selected = search_filter[label] == k

            -- If the user selects a new value, update the search filter
            if ImGui.Selectable(k, is_selected) then
                search_filter_add(label, k)
            end

            -- Make sure this is the selected/visible item in the dropdown
            if is_selected then
                ImGui.SetItemDefaultFocus()
            end
        end

        ImGui.EndCombo()
    end
end

-- Renders contents for the "Search" tab 
local render_search_ui = function(windowSize)
    ImGui.Text("Search the Bazaar for items")

    local halfSize = windowSize / 2

    -- Item name search input box
    search_item_name, _ = ImGui.InputText("Item Name", search_item_name, ImGuiInputTextFlags.EnterReturnsTrue)

    -- Dropdown filters, line 1
    render_search_dropdown("Class")
    ImGui.SameLine(halfSize)
    render_search_dropdown("Race", halfSize)

    -- Dropdown filters, line 2
    render_search_dropdown("Slot")
    ImGui.SameLine(halfSize)
    render_search_dropdown("Stat", halfSize)

    -- Dropdown filters, line 3
    render_search_dropdown("Type")
    ImGui.SameLine(halfSize)
    render_search_dropdown("Aug", halfSize, function(t, a, b) return tonumber(t[a]) < tonumber(t[b]) end)

    -- Dropdown filters, line 4
    render_search_dropdown("Direction")

    -- Minimum and Maximum price input boxes
    search_min_price, _ = ImGui.InputInt("Min Price", search_min_price, 0, 0)
    ImGui.SameLine(halfSize)
    search_max_price, _ = ImGui.InputInt("Max Price", search_max_price, 0, 0)

    -- Search button
    if ImGui.Button("Search") then
        search_item_name = trim_space(search_item_name)
        Write.Debug('Searching for "%s"', search_item_name)

        -- Generate a random query ID, to help us match results for display
        current_query_id = util.random_string(16)

        -- Clear the queries; keep it a single query for now
        settings['Queries'] = {} 
        settings['Queries'][current_query_id] = build_query()

        -- Signal that we want to save the settings to the INI file
        -- Saving our INI file will trigger the server script to query the bazaar
        start_save_settings = true

        -- Signal that we want to start searching for the results
        -- The server script will write query results to a CSV file
        -- This will begin to poll that CSV results file, looking for the matching queryID
        start_search = true
    end

    -- A button that can clear/reset our search
    ImGui.SameLine(80)
    if ImGui.Button("Clear") then

        -- Clear out our text boxes
        search_item_name = ""
        search_min_price = 0
        search_max_price = 0

        -- Clear the search filters
        search_filter = {}

    end
    ImGui.Separator()

    -- Display our search results
    if currently_searching then
        ImGui.Text("Searching for %s ...", search_item_name)
        ImGui.Separator()
    else
        ImGui.Text("Search Results")

        -- Results table
        if ImGui.BeginTable('BazResults', 4, ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn('QueryID', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Price', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableSetupColumn('Seller', ImGuiTableColumnFlags.DefaultSort)
            ImGui.TableHeadersRow()

            -- Iterate through the search results and display them ar rows in the table
            for i, result in ipairs(search_results) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text(result.QueryID)
                ImGui.TableNextColumn()
                if ImGui.SmallButton(result.Item..'##'..i) then
                    Write.Debug('%s clicked', result.Item)
                    mq.cmdf('/link %s', result.Item)
                end
                ImGui.TableNextColumn()
                ImGui.Text(result.Price)
                ImGui.TableNextColumn()
                if ImGui.SmallButton(result.Seller..'##'..i) then
                    Write.Debug('Navgating to to %s', result.Seller)
                    mq.cmdf('/target %s', result.Seller)
                    mq.cmd('/nav target')
                end
            end
            ImGui.EndTable()
        end
    end

end

local monitor_compare = {
    ["Equals"] = "=",
    ["Less than"] = "<",
    ["Greater than"] = ">",
} 

local monitor_items = {}
local current_monitor_item = ""
local current_monitor_compare = ""
local current_monitor_price = 0

local clear_monitor_filters = function()
    current_monitor_item = ""
    current_monitor_compare = "Less than"
    current_monitor_price = 0
end

local parse_monitor_filter = function(filter_string)
    local filter = {
        ["Price"] = 0,
        ["Compare"] = "",
    }
    for w in string.gmatch(filter_string, "(.[^/]+)") do
        local pos = string.find(w, "|")
        local key = string.sub(w, 2, pos-1)
        local value = string.sub(w, pos+1)
        filter[key] = value
    end
    return filter
end

local render_monitor_ui = function(windowSize)
    ImGui.Text("Monitor the Bazaar for items based on conditions")
    ImGui.TextColored(1, 0, 0, 1, "WARNING: This feature is not yet implemented!")
    ImGui.Separator()

    local monitor_item = {}
    local labelWidth = 80
    local inputWidth = windowSize / 3

    -- Item name search input box
    ImGui.Text("Item name")
    ImGui.SameLine(labelWidth)
    ImGui.PushItemWidth(inputWidth)
    current_monitor_item, _ = ImGui.InputText("", "", 0, 0)

    -- Comparison operator dropdown
    local compare = "Less than"
    ImGui.Text("Is")
    ImGui.SameLine(labelWidth)
    ImGui.PushItemWidth(inputWidth)
    if ImGui.BeginCombo("##compare", compare, 0) then
        for k, v in pairs(monitor_compare) do
            local is_selected = compare == monitor_compare[k]
            if ImGui.Selectable(k, is_selected) then
                current_monitor_compare = v
            end
            if is_selected then
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end

    -- Price input box
    ImGui.Text("Price")
    ImGui.SameLine(labelWidth)
    current_monitor_price, _ = ImGui.InputInt("", 0, 0, 0)

    -- Save and Clear buttons
    ImGui.SameLine(inputWidth * 2)
    if ImGui.Button("Save") then
        settings['Monitor'][current_monitor_item] = string.format("/Price|%d/Compare|%s",
            current_monitor_price, current_monitor_compare)
        save_settings(settings)
        clear_monitor_filters()
    end
    ImGui.SameLine()
    if ImGui.Button("Clear") then
        clear_monitor_filters()
    end

    ImGui.Separator()

    -- Display the monitor items
    ImGui.Text("Monitor Items")
    if ImGui.BeginTable('BazResults', 4, ImGuiTableFlags.Borders) then
        ImGui.TableSetupColumn('Item name', ImGuiTableColumnFlags.WidthFixed, inputWidth * 1.5)
        ImGui.TableSetupColumn('Is', ImGuiTableColumnFlags.WidthFixed, 20)
        ImGui.TableSetupColumn('Price', ImGuiTableColumnFlags.WidthFixed, inputWidth * 0.5)
        ImGui.TableSetupColumn('', ImGuiTableColumnFlags.DefaultSort)
        ImGui.TableHeadersRow()

        -- Iterate through the search results and display them ar rows in the table
        for name,v  in pairs(settings['Monitor']) do
            local filter = parse_monitor_filter(v)
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text(name)
            ImGui.TableNextColumn()
            ImGui.Text(filter["Compare"])
            ImGui.TableNextColumn()
            ImGui.Text(filter["Price"])
            ImGui.TableNextColumn()
            if ImGui.SmallButton('Edit##') then
                Write.Debug('%s edit clicked', name)
                --mq.cmdf('/link %s', result.Item)
            end
            ImGui.SameLine()
            if ImGui.SmallButton('Delete##') then
                Write.Debug('%s edit clicked', name)
                --mq.cmdf('/link %s', result.Item)
            end
        end
        ImGui.EndTable()
    end
end

-- Renders the main UI for the Bazaar search tool
local render_ui = function(open)
    local main_viewport = ImGui.GetMainViewport()

    -- Set the window position and size for the first run
    ImGui.SetNextWindowPos(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(600, 300, ImGuiCond.FirstUseEver)

    -- Begin the window
    local flags = 0
    if settings['General']['Window Locked'] then flags = bit32.bor(flags, ImGuiWindowFlags.NoMove) end
    local open, show = ImGui.Begin("BazMon - Bazaar Monitor and Search", true, flags)

    if not show then
        ImGui.End()
        return open
    end

    ImGui.PushItemWidth(ImGui.GetFontSize() * -12)

    local windowSize = ImGui.GetWindowWidth()

    -- Window lock button
    local lockedIcon = settings['General']['Window Locked'] and icons.FA_LOCK.."##lock" or icons.FA_UNLOCK.."##lock"
    if ImGui.Button(lockedIcon) then
        settings['General']['Window Locked'] = not settings['General']['Window Locked']
        ImGui.Locked = settings['General']['Window Locked']
        save_settings(settings)
    end

    ImGui.SameLine()

    -- Star tab bar
    if ImGui.BeginTabBar('BAZMONTABS##'..'tabs', ImGuiTabBarFlags.Reorderable) then

        -- Bazaar search tab
        if ImGui.BeginTabItem('Search') then
            render_search_ui(windowSize)
            ImGui.EndTabItem()
        end

        -- Bazaar monitor tab
        if ImGui.BeginTabItem('Monitor') then
            render_monitor_ui(windowSize)
            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end

    -- Clean up the window elements
    ImGui.Spacing()
    ImGui.PopItemWidth()
    ImGui.End()

    return open
end

-- The bind callback for the /bazmon command
-- This function is for debugging and testing purposes
-- Users should use the UI to interact with the script
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

    -- Manually add a search filter
    -- /bazmon filter set <key> <val>
    if args[1] == 'filter' and args[2] == 'set' and args[3] ~= nil and args[4] ~= nil then
        search_filter_add(args[3], args[4])
    end

    -- Get a specific search filter value
    -- /bazmon filter get <key>
    if args[1] == 'filter' and args[2] == 'get' and args[3] ~= nil then
        Write.Debug('Filter for %s = %s', args[3], search_filter[args[3]])
    end

    -- Get a specific search filter value's index from its array of valid values
    -- /bazmon filter index <key>
    if args[1] == 'filter' and args[2] == 'index' and args[3] ~= nil then
        Write.Debug('Filter for %s', args[3])
        Write.Debug('Filter for %s = %s', args[3], search_filter_index(args[3]))
    end

    -- List the search filters
    -- /bazmon filter list
    if args[1] == 'filter' and args[2] == 'list' then
        Write.Debug('Listing filters')
        for key, val in pairs(search_filter) do
            Write.Debug('Filter: %s = %s', key, val)
        end
    end

    -- List valid values for a search filter
    -- /bazmon filter values <key>
    if args[1] == 'filter' and args[2] == 'values' and args[3] ~= nil then
        local filter = util.upper_first(args[3])
        if filters[filter] == nil then
            Write.Debug('No filter for %s', filter)
            return
        end
        Write.Debug('Listing values for %s', args[3])
        for key, val in pairs(filters[filter]) do
            Write.Debug('Value: %s = %s', key, val)
        end
    end

    -- Clear the search filters
    -- /bazmon filter clear
    if args[1] == 'filter' and args[2] == 'clear' then
        Write.Debug('Clearing filters')
        search_filter = {}
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

    -- Parse the CSV file
    if args[1] == 'csv' then
        Write.Debug('Reading CSV file: %s', results_file)
        for index, result in ftcsv.parseLine(results_file, ",") do
            Write.Debug('Result[%d]: %s "%s" %s %s', index, result.QueryID, result.Item, result.Price, result.Seller)
        end
    end

end

-- Load the settings from the config file
-- If the file does not exist, write out an example config file that the user can edit
if util.file_exists(config_file) then
    Write.Info('Config file exists: %s', config_file)
    settings = ini.parse(config_file)
    
    -- Check for certain new settings that may not exist in the config file
    if not settings['General'] then
        settings['General'] = {}
    end
    if not settings['General']['Window Locked'] then
        settings['General']['Window Locked'] = false
    end
    if not settings['Monitor'] then
        settings['Monitor'] = {}
    end
    if not settings['Queries'] then
        settings['Queries'] = {}
    end
else
    Write.Info('Config file does NOT exist: %s', config_file)
    Write.Info('Writing example config to %s', config_file)
    save_settings(example_config)
    settings = example_config
end

-- Bind the bazmon command 
mq.bind('/bazmon', bazmonitor)

-- Set the MQ2LinkDB to automatically click on exact matches
mq.cmd('/link /click on')

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
