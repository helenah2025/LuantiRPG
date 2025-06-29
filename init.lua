-- Luanti RPG
-- RPG engine mod for Luanti

-- Copyright (C) 2025 Helenah, HelenasaurusRex, Helena Bolan <helenah2025@proton.me>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

rpg = {
    players = {},
    races = {},
    classes = {},
    armor_types = {},
    welcome_messages = {}
}

local mod_storage = minetest.get_mod_storage()
local char_creation = {}

-- API registration Functions
function rpg.register_race(id, def)
    rpg.races[id] = def
    rpg.races[id].id = id
end

function rpg.register_class(id, def)
    rpg.classes[id] = def
    rpg.classes[id].id = id
end

function rpg.register_armor_type(id, def)
    rpg.armor_types[id] = def
    rpg.armor_types[id].id = id
end

function rpg.register_welcome_message(message)
    table.insert(rpg.welcome_messages, message)
end

-- Stats calculation
local function calculate_stats(race_id, class_id)
    local race_stats = rpg.races[race_id].base_statistics
    local class_bonus = rpg.classes[class_id].bonus_statistics
    
    return {
        strength = race_stats.strength + class_bonus.strength,
        agility = race_stats.agility + class_bonus.agility,
        stamina = race_stats.stamina + class_bonus.stamina,
        intellect = race_stats.intellect + class_bonus.intellect,
        spirit = race_stats.spirit + class_bonus.spirit
    }
end

-- Character creation formspec
local function show_character_creation(player)
    local player_name = player:get_player_name()
    local formspec = "size[10,8]" ..
        "allow_close[false]" ..
        "label[0.5,0.7;Character Creation]" ..
        "label[0.5,1.5;Select Race:]" ..
        "textlist[0.5,2;4,4;race_list;"
    
    -- Build race list
    local race_names = {}
    for id, race in pairs(rpg.races) do
        table.insert(race_names, race.display_name)
    end
    table.sort(race_names)
    formspec = formspec .. table.concat(race_names, ",") .. ";0]"
    
    -- Class list (initially empty)
    formspec = formspec .. "label[5.5,1.5;Select Class:]" ..
        "textlist[5.5,2;4,4;class_list;No race selected;1]"
    
    -- Gender selection
    formspec = formspec .. "label[0.5,6;Gender:]" ..
        "dropdown[0.5,6.5;4;gender;Male,Female;1]" ..
        "button_exit[5.5,6;4,1;create;Create Character]"
    
    minetest.show_formspec(player_name, "LuantiRPG:creation", formspec)
end

-- Update class list based on selected race
local function update_class_list(player, race_index)
    local player_name = player:get_player_name()
    local race_name = char_creation[player_name].race_names[race_index]
    local race_id
    
    -- Find race ID from display name
    for id, def in pairs(rpg.races) do
        if def.display_name == race_name then
            race_id = id
            break
        end
    end
    
    if not race_id then return end
    
    char_creation[player_name].race_id = race_id
    local class_names = {}
    
    for _, class_id in ipairs(rpg.races[race_id].playable_classes) do
        if rpg.classes[class_id] then
            table.insert(class_names, rpg.classes[class_id].display_name)
        end
    end
    
    table.sort(class_names)
    char_creation[player_name].class_names = class_names

    -- Rebuild the entire formspec with list of playable classes for selected race
    local formspec = "size[10,8]" ..
        "allow_close[false]" ..
        "label[0.5,0.7;Character Creation]" ..
        "label[0.5,1.5;Select Race:]" ..
        "textlist[0.5,2;4,4;race_list;" .. table.concat(char_creation[player_name].race_names, ",") .. ";" .. race_index .. "]" ..
        "label[5.5,1.5;Select Class:]" ..
        "textlist[5.5,2;4,4;class_list;" .. table.concat(class_names, ",") .. ";0]" ..
        "label[0.5,6;Gender:]" ..
        "dropdown[0.5,6.5;4;gender;Male,Female;1]" ..
        "button_exit[5.5,6;4,1;create;Create Character]"  

    minetest.show_formspec(player_name, "LuantiRPG:creation", formspec)
end

-- Handle formspec input
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "LuantiRPG:creation" then return end
    
    local player_name = player:get_player_name()
    if not char_creation[player_name] then return end
    
    -- Handle race selection
    if fields.race_list then
        local event = minetest.explode_textlist_event(fields.race_list)
        if event.type == "CHG" then
            update_class_list(player, event.index)
        end
        return
    end
    
    -- Handle class selection
    if fields.class_list and char_creation[player_name].class_names then
        local event = minetest.explode_textlist_event(fields.class_list)
        if event.type == "CHG" then
            char_creation[player_name].class_index = event.index
        end
        return
    end
    
    -- Handle character creation
    if fields.create then
        local race_id = char_creation[player_name].race_id
        local class_index = char_creation[player_name].class_index
        local class_names = char_creation[player_name].class_names
        
        if not race_id or not class_index or not class_names then
            minetest.chat_send_player(player_name, "Please select both race and class!")
            return
        end
        
        -- Get class ID from display name
        local class_name = class_names[class_index]
        local class_id
        for id, def in pairs(rpg.classes) do
            if def.display_name == class_name then
                class_id = id
                break
            end
        end
        
        if not class_id then return end
        
        -- Save player data
        rpg.players[player_name] = {
            race = race_id,
            class = class_id,
            gender = fields.gender or "Male",
            stats = calculate_stats(race_id, class_id),
            level = 1,
            experience = 0
        }
        
        -- Save to storage
        mod_storage:set_string(player_name, minetest.write_json(rpg.players[player_name]))
        
        -- Teleport to starting location
        local start_pos = rpg.races[race_id].starting_coordinates
        player:set_pos(start_pos)

        -- Unfreeze player
        player:set_physics_override({speed = 1, jump = 1})
        
        -- Cleanup
        char_creation[player_name] = nil

        -- Check for welcome messages and send them to player
        for _, template in ipairs(rpg.welcome_messages) do
            local message = template
                :gsub("{player_name}", player_name)
                :gsub("{race}", rpg.races[race_id].display_name)
                :gsub("{class}", rpg.classes[class_id].display_name)
                :gsub("{level}", tostring(rpg.players[player_name].level))
--                :gsub("{strength}", tostring(stats.strength))
--                :gsub("{agility}", tostring(stats.agility))
--                :gsub("{stamina}", tostring(stats.stamina))
--                :gsub("{intellect}", tostring(stats.intellect))
--                :gsub("{spirit}", tostring(stats.spirit))

            minetest.chat_send_player(player_name, message)
        end
    end
end)

-- Handle player joining
minetest.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()
    local data = mod_storage:get_string(player_name)
    
    if data ~= "" then
        rpg.players[player_name] = minetest.parse_json(data)
    else
        -- Initialize character creation
        char_creation[player_name] = {
            race_names = {},
            class_names = {},
            race_index = 1,
            class_index = nil
        }
        
        -- Build race name list
        for id, race in pairs(rpg.races) do
            table.insert(char_creation[player_name].race_names, race.display_name)
        end
        table.sort(char_creation[player_name].race_names)
        
        -- Freeze player
        -- Prevents the player from moving until they have completed the creation of their character
        player:set_physics_override({speed = 0, jump = 0})
        show_character_creation(player)
    end
end)

-- Handle player leaving
minetest.register_on_leaveplayer(function(player)
    local player_name = player:get_player_name()
    if rpg.players[player_name] then
        mod_storage:set_string(player_name, minetest.write_json(rpg.players[player_name]))
    end
end)

-- Prevent closing formspec without creating character
minetest.register_on_leaveplayer(function(player)
    local player_name = player:get_player_name()
    if char_creation[player_name] then
        minetest.kick_player(player_name, "You must complete character creation")
    end
end)
