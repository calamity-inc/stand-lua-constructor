-- Constructor
-- by Hexarobi
-- A Lua Script for the Stand mod menu for GTA5
-- Allows for constructing custom vehicles and maps
-- https://github.com/hexarobi/stand-lua-constructor

local SCRIPT_VERSION = "0.9.8"
local AUTO_UPDATE_BRANCHES = {
    { "main", {}, "More stable, but updated less often.", "main", },
    { "dev", {}, "Cutting edge updates, but less stable.", "dev", },
}
local SELECTED_BRANCH_INDEX = 1

---
--- Auto-Updater
---

local auto_update_source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-constructor/main/Constructor.lua"

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
            function(result, headers, status_code)
                local function parse_auto_update_result(result, headers, status_code)
                    local error_prefix = "Error downloading auto-updater: "
                    if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                    if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                    filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                    local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                    if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                    file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                end
                auto_update_complete = parse_auto_update_result(result, headers, status_code)
            end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 20) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

local function auto_update_branch(selected_branch)
    local branch_source_url = auto_update_source_url:gsub("/main/", "/"..selected_branch.."/")
    auto_updater.run_auto_update({source_url=branch_source_url, script_relpath=SCRIPT_RELPATH, verify_file_begins_with="--"})
end
auto_update_branch(AUTO_UPDATE_BRANCHES[SELECTED_BRANCH_INDEX][1])

---
--- Dependencies
---

local loading_menu = menu.divider(menu.my_root(), "Please wait...", {}, "Loading dependencies...")

util.require_natives(1660775568)
local status, natives = pcall(require, "natives-1660775568")
if not status then error("Could not natives lib. Make sure it is selected under Stand > Lua Scripts > Repository > natives-1660775568") end

local status, json = pcall(require, "json")
if not status then error("Could not load json lib. Make sure it is selected under Stand > Lua Scripts > Repository > json") end

local inspect = auto_updater.require_with_auto_update({
    source_url="https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua",
    script_relpath="lib/inspect.lua",
    verify_file_begins_with="local",
})

local constructor_lib = auto_updater.require_with_auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-constructor/main/lib/constructor/constructor_lib.lua",
    script_relpath="lib/constructor/constructor_lib.lua",
    verify_file_begins_with="--",
})

menu.delete(loading_menu)

---
--- Data
---

local config = {
    source_code_branch = "main",
    edit_offset_step = 10,
    edit_rotation_step = 15,
    add_attachment_gun_active = false,
    debug = true,
    show_previews = true,
    preview_camera_distance = 3,
    preview_bounding_box_color = {r=255,g=0,b=255,a=255},
    deconstruct_all_spawned_constructs_on_unload = true,
    drive_spawned_vehicles = true,
}

local CONSTRUCTS_DIR = filesystem.store_dir() .. 'Constructor\\constructs\\'
filesystem.mkdirs(CONSTRUCTS_DIR)

local spawned_constructs = {}
local last_spawned_construct
local menus = {
    children = {}
}

--local example_construct = {
--    name="Police",
--    model="police",
--    handle=1234,
--    options = {},
--    attachments = {},
--}
--
--local example_attachment = {
--    name="Child #1",            -- Name for this attachment
--    handle=5678,                -- Handle for this attachment
--    root=example_policified_vehicle,
--    parent=1234,                -- Parent Handle
--    bone_index = 0,             -- Which bone of the parent should this attach to
--    offset = { x=0, y=0, z=0 },  -- Offset coords from parent
--    rotation = { x=0, y=0, z=0 },-- Rotation from parent
--    children = {
--        -- Other attachments
--        reflection_axis = { x = true, y = false, z = false },   -- Which axis should be reflected about
--    },
--    is_visible = true,
--    has_collision = true,
--    has_gravity = true,
--    options = { is_light_disabled = true },   -- If true this light will always be off, regardless of siren settings
--}

local ENTITY_TYPES = {"PED", "VEHICLE", "OBJECT"}

-- Good props for cop lights
-- prop_air_lights_02a blue
-- prop_air_lights_02b red
-- h4_prop_battle_lights_floorblue
-- h4_prop_battle_lights_floorred
-- prop_wall_light_10a
-- prop_wall_light_10b
-- prop_wall_light_10c
-- hei_prop_wall_light_10a_cr

local available_attachments = {
    {
        name = "Lights",
        objects = {
            {
                name = "Red Spinning Light",
                model = "hei_prop_wall_light_10a_cr",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = 180, y = 0, z = 0 },
                options = { options = { is_light_disabled = true } },
                children = {
                    {
                        model = "prop_wall_light_10a",
                        offset = { x = 0, y = 0.01, z = 0 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                },
            },
            {
                name = "Blue Spinning Light",
                model = "hei_prop_wall_light_10a_cr",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = 180, y = 0, z = 0 },
                options = { options = { is_light_disabled = true } },
                children = {
                    {
                        model = "prop_wall_light_10b",
                        offset = { x = 0, y = 0.01, z = 0 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                },
            },
            {
                name = "Yellow Spinning Light",
                model = "hei_prop_wall_light_10a_cr",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = 180, y = 0, z = 0 },
                options = { is_light_disabled = true },
                children = {
                    {
                        model = "prop_wall_light_10c",
                        offset = { x = 0, y = 0.01, z = 0 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                },
            },

            {
                name = "Combo Red+Blue Spinning Light",
                model = "hei_prop_wall_light_10a_cr",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = 180, y = 0, z = 0 },
                options = { is_light_disabled = true },
                children = {
                    {
                        model = "prop_wall_light_10b",
                        offset = { x = 0, y = 0.01, z = 0 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                    {
                        model = "prop_wall_light_10a",
                        offset = { x = 0, y = 0.01, z = 0 },
                        rotation = { x = 0, y = 0, z = 180 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                },
                --reflection = {
                --    model = "hei_prop_wall_light_10a_cr",
                --    reflection_axis = { x = true, y = false, z = false },
                --    options = { is_light_disabled = true },
                --    children = {
                --        {
                --            model = "prop_wall_light_10a",
                --            offset = { x = 0, y = 0.01, z = 0 },
                --            rotation = { x = 0, y = 0, z = 180 },
                --            options = { is_light_disabled = false },
                --            bone_index = 1,
                --        },
                --    },
                --}
            },

            {
                name = "Pair of Spinning Lights",
                model = "hei_prop_wall_light_10a_cr",
                offset = { x = 0.3, y = 0, z = 1 },
                rotation = { x = 180, y = 0, z = 0 },
                options = { is_light_disabled = true },
                children = {
                    {
                        model = "prop_wall_light_10b",
                        offset = { x = 0, y = 0.01, z = 0 },
                        options = {
                            is_light_disabled = false,
                            bone_index = 1,
                        },
                    },
                    {
                        model = "hei_prop_wall_light_10a_cr",
                        reflection_axis = { x = true, y = false, z = false },
                        options = { is_light_disabled = true },
                        children = {
                            {
                                model = "prop_wall_light_10a",
                                offset = { x = 0, y = 0.01, z = 0 },
                                rotation = { x = 0, y = 0, z = 180 },
                                options = {
                                    is_light_disabled = false,
                                    bone_index = 1,
                                },
                            },
                        },
                    }
                },
            },

            {
                name = "Short Spinning Red Light",
                model = "hei_prop_wall_alarm_on",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = -90, y = 0, z = 0 },
            },
            {
                name = "Small Red Warning Light",
                model = "prop_warninglight_01",
                offset = { x = 0, y = 0, z = 1 },
            },

            {
                name = "Blue Recessed Light",
                model = "h4_prop_battle_lights_floorblue",
                offset = { x = 0, y = 0, z = 0.75 },
            },
            {
                name = "Red Recessed Light",
                model = "h4_prop_battle_lights_floorred",
                offset = { x = 0, y = 0, z = 0.75 },
            },
            {
                name = "Red/Blue Pair of Recessed Lights",
                model = "h4_prop_battle_lights_floorred",
                offset = { x = 0.3, y = 0, z = 1 },
                children = {
                    {
                        model = "h4_prop_battle_lights_floorblue",
                        reflection_axis = { x = true, y = false, z = false },
                    }
                }
            },
            {
                name = "Blue/Red Pair of Recessed Lights",
                model = "h4_prop_battle_lights_floorblue",
                offset = { x = 0.3, y = 0, z = 1 },
                children = {
                    {
                        model = "h4_prop_battle_lights_floorred",
                        reflection_axis = { x = true, y = false, z = false },
                    }
                }
            },

            -- Flashing is still kinda wonky for networking
            {
                name = "Flashing Recessed Lights",
                model = "h4_prop_battle_lights_floorred",
                offset = { x = 0.3, y = 0, z = 1 },
                flash_start_on = false,
                children = {
                    {
                        model = "h4_prop_battle_lights_floorblue",
                        reflection_axis = { x = true, y = false, z = false },
                        flash_start_on = true,
                    }
                }
            },
            {
                name = "Alternating Pair of Recessed Lights",
                model = "h4_prop_battle_lights_floorred",
                offset = { x = 0.3, y = 0, z = 1 },
                flash_start_on = true,
                children = {
                    {
                        model = "h4_prop_battle_lights_floorred",
                        reflection_axis = { x = true, y = false, z = false },
                        flash_start_on = false,
                        children = {
                            {
                                model = "h4_prop_battle_lights_floorblue",
                                flash_start_on = true,
                            }
                        }
                    },
                    {
                        model = "h4_prop_battle_lights_floorblue",
                        flash_start_on = true,
                    }
                }
            },

            {
                name = "Red Disc Light",
                model = "prop_runlight_r",
                offset = { x = 0, y = 0, z = 1 },
            },
            {
                name = "Blue Disc Light",
                model = "prop_runlight_b",
                offset = { x = 0, y = 0, z = 1 },
            },

            {
                name = "Blue Pole Light",
                model = "prop_air_lights_02a",
                offset = { x = 0, y = 0, z = 1 },
            },
            {
                name = "Red Pole Light",
                model = "prop_air_lights_02b",
                offset = { x = 0, y = 0, z = 1 },
            },

            {
                name = "Red Angled Light",
                model = "prop_air_lights_04a",
                offset = { x = 0, y = 0, z = 1 },
            },
            {
                name = "Blue Angled Light",
                model = "prop_air_lights_05a",
                offset = { x = 0, y = 0, z = 1 },
            },

            {
                name = "Cone Light",
                model = "prop_air_conelight",
                offset = { x = 0, y = 0, z = 1 },
                rotation = { x = 0, y = 0, z = 0 },
            },

            -- This is actually 2 lights, spaced 20 feet apart.
            --{
            --    name="Blinking Red Light",
            --    model="hei_prop_carrier_docklight_01",
            --}
        },
    },
    {
        name = "Props",
        objects = {
            {
                name = "Riot Shield",
                model = "prop_riot_shield",
                rotation = { x = 180, y = 180, z = 0 },
            },
            {
                name = "Ballistic Shield",
                model = "prop_ballistic_shield",
                rotation = { x = 180, y = 180, z = 0 },
            },
            {
                name = "Minigun",
                model = "prop_minigun_01",
                rotation = { x = 0, y = 0, z = 90 },
            },
            {
                name = "Monitor Screen",
                model = "hei_prop_hei_monitor_police_01",
            },
            {
                name = "Bomb",
                model = "prop_ld_bomb_anim",
            },
            {
                name = "Bomb (open)",
                model = "prop_ld_bomb_01_open",
            },


        },
    },
    {
        name = "Vehicles",
        objects = {
            {
                name = "Police Cruiser",
                model = "police",
                type = "VEHICLE",
            },
            {
                name = "Police Buffalo",
                model = "police2",
                type = "VEHICLE",
            },
            {
                name = "Police Sports",
                model = "police3",
                type = "VEHICLE",
            },
            {
                name = "Police Van",
                model = "policet",
                type = "VEHICLE",
            },
            {
                name = "Police Bike",
                model = "policeb",
                type = "VEHICLE",
            },
            {
                name = "FIB Cruiser",
                model = "fbi",
                type = "VEHICLE",
            },
            {
                name = "FIB SUV",
                model = "fbi2",
                type = "VEHICLE",
            },
            {
                name = "Sheriff Cruiser",
                model = "sheriff",
                type = "VEHICLE",
            },
            {
                name = "Sheriff SUV",
                model = "sheriff2",
                type = "VEHICLE",
            },
            {
                name = "Unmarked Cruiser",
                model = "police3",
                type = "VEHICLE",
            },
            {
                name = "Snowy Rancher",
                model = "policeold1",
                type = "VEHICLE",
            },
            {
                name = "Snowy Cruiser",
                model = "policeold2",
                type = "VEHICLE",
            },
            {
                name = "Park Ranger",
                model = "pranger",
                type = "VEHICLE",
            },
            {
                name = "Riot Van",
                model = "riot",
                type = "VEHICLE",
            },
            {
                name = "Riot Control Vehicle (RCV)",
                model = "riot2",
                type = "VEHICLE",
            },
        },
    },
}

---
--- Utilities
---

function table.table_copy(obj, depth)
    if depth == nil then depth = 0 end
    if depth > 1000 then error("Max table depth reached") end
    depth = depth + 1
    if type(obj) ~= 'table' then
        return obj
    end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do
        res[table.table_copy(k, depth)] = table.table_copy(v, depth)
    end
    return res
end

function string.starts(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

-- From https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
local function array_remove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

local function clear_references(attachment)
    attachment.root = nil
    attachment.parent = nil
    if attachment.children then
        for _, child_attachment in pairs(attachment.children) do
            clear_references(child_attachment)
        end
    end
end

local function copy_construct_plan(construct_plan)
    --return constructor_lib.clone_attachment(construct_plan)
    --util.log(inspect(attachment.vehicle_attributes.paint))
    local is_root = construct_plan == construct_plan.parent
    clear_references(construct_plan)
    local construct = table.table_copy(construct_plan)
    if is_root then
        construct.root = construct
        construct.parent = construct
    end
    return construct
end

local function add_attachment_to_construct(attachment)
    constructor_lib.add_attachment_to_construct(attachment)
    menus.rebuild_attachment_menu(attachment)
    attachment.menus.refresh()
    attachment.menus.focus()
end

---
--- Preview
---

local current_preview
local next_preview
local minVec = v3.new()
local maxVec = v3.new()

local function rotation_to_direction(rotation)
    local adjusted_rotation =
    {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction =
    {
        x = -math.sin(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)),
        y =  math.cos(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)),
        z =  math.sin(adjusted_rotation.x)
    }
    return direction
end

local function get_offset_from_camera(distance)
    local cam_rot = CAM.GET_FINAL_RENDERED_CAM_ROT(0)
    local cam_pos = CAM.GET_FINAL_RENDERED_CAM_COORD()
    local direction = rotation_to_direction(cam_rot)
    local destination =
    {
        x = cam_pos.x + direction.x * distance,
        y = cam_pos.y + direction.y * distance,
        z = cam_pos.z + direction.z * distance
    }
    return destination
end

local function calculate_model_size(model)
    MISC.GET_MODEL_DIMENSIONS(model, minVec, maxVec)
    return (maxVec:getX() - minVec:getX()), (maxVec:getY() - minVec:getY()), (maxVec:getZ() - minVec:getZ())
end

local function calculate_construct_size(construct, child_attachment)
    if construct.dimensions == nil then construct.dimensions = {l=0, w=0, h=0, min_vec={x=0,y=0,z=0}, max_vec={x=0,y=0,z=0}} end
    if child_attachment == nil then child_attachment = construct end
    if child_attachment.offset == nil then child_attachment.offset = {x=0,y=0,z=0} end
    MISC.GET_MODEL_DIMENSIONS(child_attachment.hash, minVec, maxVec)

    construct.dimensions.min_vec.x = math.min(construct.dimensions.min_vec.x, minVec:getX() + child_attachment.offset.x)
    construct.dimensions.min_vec.y = math.min(construct.dimensions.min_vec.y, minVec:getY() + child_attachment.offset.y)
    construct.dimensions.min_vec.z = math.min(construct.dimensions.min_vec.z, minVec:getZ() + child_attachment.offset.z)

    construct.dimensions.max_vec.x = math.max(construct.dimensions.max_vec.x, maxVec:getX() + child_attachment.offset.x)
    construct.dimensions.max_vec.y = math.max(construct.dimensions.max_vec.y, maxVec:getY() + child_attachment.offset.y)
    construct.dimensions.max_vec.z = math.max(construct.dimensions.max_vec.z, maxVec:getZ() + child_attachment.offset.z)

    if child_attachment.children then
        for _, child in pairs(child_attachment.children) do
            calculate_construct_size(construct, child)
        end
    end

    construct.dimensions.l = (construct.dimensions.max_vec.x - construct.dimensions.min_vec.x)
    construct.dimensions.w = (construct.dimensions.max_vec.y - construct.dimensions.min_vec.y)
    construct.dimensions.h = (construct.dimensions.max_vec.z - construct.dimensions.min_vec.z)
end

local function remove_preview()
    if current_preview ~= nil then
        if config.debug then util.log("Removing preview "..current_preview.name) end
        constructor_lib.remove_attachment(current_preview)
        current_preview = nil
    end
end

local function calculate_camera_distance(attachment)
    if attachment.hash == nil then attachment.hash = util.joaat(attachment.model) end
    constructor_lib.load_hash_for_attachment(attachment)
    local l, w, h = calculate_model_size(attachment.hash, minVec, maxVec)
    attachment.camera_distance = math.max(l, w, h) + config.preview_camera_distance
    --calculate_construct_size(attachment)
    --attachment.camera_distance = math.max(attachment.dimensions.l, attachment.dimensions.w, attachment.dimensions.h) + config.preview_camera_distance
end

local function add_preview(construct_plan)
    if config.show_previews == false then return end
    if construct_plan == nil then return end
    next_preview = construct_plan
    remove_preview()
    util.yield(250)
    if next_preview == construct_plan then
        local attachment = copy_construct_plan(construct_plan)
        attachment.name = attachment.model.." (Preview)"
        attachment.root = attachment
        attachment.parent = attachment
        attachment.is_preview = true
        calculate_camera_distance(attachment)
        attachment.position = get_offset_from_camera(attachment.camera_distance)
        --if config.debug then util.log("Adding preview "..attachment.name) end
        current_preview = constructor_lib.attach_attachment_with_children(attachment)
    end
end

local function disable_attachment_collision(attachment)
    ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(attachment.handle, false, true)
    for _, child_attachment in pairs(attachment.children) do
        disable_attachment_collision(child_attachment)
    end
end

local function update_preview_tick()
    if current_preview ~= nil then
        current_preview.position = get_offset_from_camera(current_preview.camera_distance)
        current_preview.rotation.z = current_preview.rotation.z + 2
        constructor_lib.update_attachment(current_preview)
        constructor_lib.draw_bounding_box(current_preview.handle, config.preview_bounding_box_color)
        disable_attachment_collision(current_preview)
    end
end

local function freeze_attachment(attachment)
    ENTITY.FREEZE_ENTITY_POSITION(attachment.handle, attachment.options.is_frozen)
    for _, child_attachment in pairs(attachment.children) do
        freeze_attachment(child_attachment)
    end
end

local function frozen_attachment_tick()
    for _, spawned_construct in pairs(spawned_constructs) do
        freeze_attachment(spawned_construct)
    end
end

---
--- Tick Handler
---

local function get_aim_info()
    local outptr = memory.alloc(4)
    local success = PLAYER.GET_ENTITY_PLAYER_IS_FREE_AIMING_AT(players.user(), outptr)
    local aim_info = {handle=0}
    if success then
        local handle = memory.read_int(outptr)
        if ENTITY.DOES_ENTITY_EXIST(handle) then
            aim_info.handle = handle
        end
        if ENTITY.GET_ENTITY_TYPE(handle) == 1 then
            local vehicle = PED.GET_VEHICLE_PED_IS_IN(handle, false)
            if vehicle ~= 0 then
                if VEHICLE.GET_PED_IN_VEHICLE_SEAT(vehicle, -1) then
                    handle = vehicle
                    aim_info.handle = handle
                end
            end
        end
        aim_info.hash = ENTITY.GET_ENTITY_MODEL(handle)
        aim_info.model = util.reverse_joaat(aim_info.hash)
        aim_info.health = ENTITY.GET_ENTITY_HEALTH(handle)
        aim_info.type = ENTITY_TYPES[ENTITY.GET_ENTITY_TYPE(handle)]
    end
    memory.free(outptr)
    return aim_info
end

local was_key_down = false
local function aim_info_tick()
    if not config.add_attachment_gun_active then return end
    local info = get_aim_info()
    if info.handle ~= 0 then
        local text = "Press J to add " .. info.type .. " `" .. info.model .. "` to construct " .. config.add_attachment_gun_recipient.name
        directx.draw_text(0.5, 0.3, text, 5, 0.5, {r=1,g=1,b=1,a=1}, true)
        if util.is_key_down(0x4A) then
            if was_key_down == false then
                util.toast("Attaching "..info.model)
                add_attachment_to_construct({
                    parent=config.add_attachment_gun_recipient,
                    root=config.add_attachment_gun_recipient.root,
                    hash=info.hash,
                    model=info.model,
                })
                config.add_attachment_gun_recipient.root.menus.refresh()
            end
            was_key_down = true
        else
            was_key_down = false
        end
    end
end

local function set_attachment_edit_menu_sensitivity(attachment, offset_step, rotation_step)
    if (attachment.menus ~= nil and attachment.menus.edit_position_x ~= nil) then
        menu.set_step_size(attachment.menus.edit_position_x, offset_step)
        menu.set_step_size(attachment.menus.edit_position_y, offset_step)
        menu.set_step_size(attachment.menus.edit_position_z, offset_step)
        menu.set_step_size(attachment.menus.edit_offset_x, offset_step)
        menu.set_step_size(attachment.menus.edit_offset_y, offset_step)
        menu.set_step_size(attachment.menus.edit_offset_z, offset_step)
        menu.set_step_size(attachment.menus.edit_rotation_x, rotation_step)
        menu.set_step_size(attachment.menus.edit_rotation_y, rotation_step)
        menu.set_step_size(attachment.menus.edit_rotation_z, rotation_step)
    end
    for _, child_attachment in pairs(attachment.children) do
        set_attachment_edit_menu_sensitivity(child_attachment, offset_step, rotation_step)
    end
end

local is_fine_tune_sensitivity_active = false
local function sensitivity_modifier_check_tick()
    if util.is_key_down(0x10) then
            -- or PAD.IS_CONTROL_JUST_PRESSED(0, 37) then
        --PAD.DISABLE_CONTROL_ACTION(0, 37)
        if is_fine_tune_sensitivity_active == false then
            for _, construct in pairs(spawned_constructs) do
                set_attachment_edit_menu_sensitivity(construct, 1, 1)
            end
            is_fine_tune_sensitivity_active = true
        end
    else
        if is_fine_tune_sensitivity_active == true then
            for _, construct in pairs(spawned_constructs) do
                set_attachment_edit_menu_sensitivity(construct, config.edit_offset_step, config.edit_rotation_step)
            end
            is_fine_tune_sensitivity_active = false
        end
    end
end

local function draw_editing_bounding_box(attachment)
    if attachment.is_editing and menu.is_open() then
        constructor_lib.draw_bounding_box(attachment.handle, config.preview_bounding_box_color)
    end
    for _, child_attachment in pairs(attachment.children) do
        draw_editing_bounding_box(child_attachment)
    end
end

local function draw_editing_attachment_bounding_box_tick()
    for _, construct in pairs(spawned_constructs) do
        draw_editing_bounding_box(construct)
    end
end

local function animate_peds(attachment)
    if attachment.type == "PED" and attachment.ped_animation ~= nil then
        constructor_lib.animate_peds(attachment)
    end
    for _, child_attachment in pairs(attachment.children) do
        animate_peds(child_attachment)
    end
end

local function ped_animation_tick()
    for _, spawned_construct in pairs(spawned_constructs) do
        animate_peds(spawned_construct)
    end
end

---
--- Construct Management
---

local function create_construct_from_vehicle(vehicle_handle)
    if config.debug then util.log("Creating construct from vehicle handle "..vehicle_handle) end
    for _, construct in pairs(spawned_constructs) do
        if construct.handle == vehicle_handle then
            util.toast("Vehicle is already a construct")
            menu.focus(construct.menus.name)
            return
        end
    end
    local construct = copy_construct_plan(constructor_lib.construct_base)
    construct.type = "VEHICLE"
    construct.handle = vehicle_handle
    construct.root = construct
    construct.parent = construct
    construct.hash = ENTITY.GET_ENTITY_MODEL(vehicle_handle)
    construct.model = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(construct.hash)
    constructor_lib.set_attachment_defaults(construct)
    table.insert(spawned_constructs, construct)
    last_spawned_construct = construct
    return construct
end

local function save_vehicle(construct)
    if construct.author == nil then construct.author = players.get_name(players.user()) end
    if construct.created == nil then construct.created = os.date("!%Y-%m-%dT%H:%M:%SZ") end
    if construct.version == nil then construct.version = "Constructor "..SCRIPT_VERSION.." / "..constructor_lib.LIB_VERSION end
    local filepath = CONSTRUCTS_DIR .. construct.name .. ".json"
    local file = io.open(filepath, "wb")
    if not file then error("Cannot write to file " .. filepath, TOAST_ALL) end
    local content = json.encode(constructor_lib.serialize_attachment(construct))
    if content == "" or (not string.starts(content, "{")) then
        util.toast("Cannot save vehicle: Error serializing.", TOAST_ALL)
        return
    end
    --util.toast(content, TOAST_ALL)
    file:write(content)
    file:close()
    util.toast("Saved ".. construct.name)
    menus.rebuild_load_construct_menu()
end

---
--- Construct Spawners
---

local function spawn_construct_from_plan(construct_plan)
    local construct = copy_construct_plan(construct_plan)
    calculate_camera_distance(construct)
    construct.position = get_offset_from_camera(construct.camera_distance)
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(players.user())
    construct.heading = ENTITY.GET_ENTITY_HEADING(target_ped)
    construct.root = construct
    construct.parent = construct
    constructor_lib.reattach_attachment_with_children(construct)
    table.insert(spawned_constructs, construct)
    last_spawned_construct = construct
    menus.refresh_loaded_constructs()
    menus.rebuild_attachment_menu(construct)
    construct.menus.refresh()
    construct.menus.focus()
    if construct.type == "VEHICLE" and config.drive_spawned_vehicles then
        PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), construct.handle, -1)
        local previous_frozen_state = construct.is_frozen
        construct.is_frozen = true
        constructor_lib.update_attachment(construct)
        util.yield(3000)
        construct.is_frozen = previous_frozen_state
        constructor_lib.update_attachment(construct)
    end
end

local function construct_from_plan(construct_plan)
    if construct_plan == construct_plan.parent then
        spawn_construct_from_plan(construct_plan)
    else
        add_attachment_to_construct(construct_plan)
    end
end

local function delete_construct(construct)
    constructor_lib.remove_attachment_from_parent(construct)
    entities.delete_by_handle(construct.handle)
    array_remove(spawned_constructs, function(t, i)
        local spawned_construct = t[i]
        return spawned_construct ~= construct
    end)
    menus.refresh_loaded_constructs()
end

---
--- File Loaders
---

local function read_file(filepath)
    local file = io.open(filepath, "r")
    if file then
        local status, data = pcall(function() return file:read("*a") end)
        if not status then
            util.toast("Invalid construct file. "..filepath, TOAST_ALL)
            return
        end
        file:close()
        return data
    else
        error("Could not read file '" .. filepath .. "'", TOAST_ALL)
    end
end

local function load_construct_plan_from_xml_file(filepath)
    local data = read_file(filepath)
    if not data then return end
    local construct_plan = constructor_lib.convert_xml_to_construct_plan(data)
    if not construct_plan then
        util.toast("Failed to load XML file: "..filepath, TOAST_ALL)
        return
    end
    return construct_plan
end

local function load_construct_plan_from_json_file(filepath)
    local data = read_file(filepath)
    if not data then return end
    return json.decode(data)
end

local function load_construct_plan_file(construct_plan_file)
    if construct_plan_file.ext == "json" then
        construct_plan_file = load_construct_plan_from_json_file(construct_plan_file.filepath)
    elseif construct_plan_file.ext == "xml" then
        construct_plan_file = load_construct_plan_from_xml_file(construct_plan_file.filepath)
        if not construct_plan_file then return end
        construct_plan_file.name = construct_plan_file.filename
    end
    if not construct_plan_file then
        util.toast("Could not load construct plan file "..construct_plan_file.filepath, TOAST_ALL)
        return
    end
    if construct_plan_file.version and string.find(construct_plan_file.version, "Jackz") then
        construct_plan_file = constructor_lib.convert_jackz_to_construct_plan(construct_plan_file)
        if not construct_plan_file then
            util.toast("Could not load Jackz Vehicle file "..construct_plan_file.filepath, TOAST_ALL)
            return
        end
    end
    if not construct_plan_file.target_version then
        util.toast("Invalid construct file format. Missing target_version. "..construct_plan_file.filepath, TOAST_ALL)
        return
    end
    return construct_plan_file
end

local function load_construct_plans_files_from_dir(directory)
    local construct_plan_files = {}
    for _, filepath in ipairs(filesystem.list_files(directory)) do
        local construct_plan_file
        if filesystem.is_dir(filepath) then
            local _, dirname = string.match(filepath, "(.-)([^\\/]-%.?)$")
            construct_plan_file = {
                is_directory=true,
                filepath=filepath,
                filename=dirname,
                name=dirname,
            }
        else
            local _, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
            construct_plan_file = {
                is_directory=false,
                filepath=filepath,
                filename=filename,
                name=filename,
                ext=ext
            }
        end
        table.insert(construct_plan_files, construct_plan_file)
    end
    return construct_plan_files
end


---
--- Prop Search
---

local PROPS_PATH = filesystem.resources_dir().."objects.txt"
--local PEDS_PATH = filesystem.resources_dir().."peds.txt"
--local VEHICLES_PATH = filesystem.resources_dir().."vehicles.txt"

local function search_props(query)
    local results = {}
    for prop in io.lines(PROPS_PATH) do
        local i, j = prop:find(query)
        if i then
            table.insert(results, { prop = prop, distance = j - i })
        end
    end
    table.sort(results, function(a, b) return a.distance > b.distance end)
    return results
end

local function clear_menu_list(t)
    for k, h in pairs(t) do
        pcall(menu.delete, h)
        t[k] = nil
    end
end

---
--- Dynamic Menus
---

menus.rebuild_add_attachments_menu = function(attachment)
    if attachment.menus.add_attachment_categories ~= nil then
        return
    end
    attachment.menus.add_attachment_categories = {}

    for _, category in pairs(available_attachments) do
        local category_menu = menu.list(attachment.menus.add_attachment, category.name)
        for _, available_attachment in pairs(category.objects) do
            local menu_item = menu.action(category_menu, available_attachment.name, {}, "", function()
                local child_attachment = copy_construct_plan(available_attachment)
                child_attachment.root = attachment.root
                child_attachment.parent = attachment
                construct_from_plan(child_attachment)
            end)
            menu.on_focus(menu_item, function(direction) if direction ~= 0 then add_preview(available_attachment) end end)
            menu.on_blur(menu_item, function(direction) if direction ~= 0 then remove_preview() end end)
        end
        table.insert(attachment.menus.add_attachment_categories, category_menu)
    end

    attachment.menus.search_results = {}
    attachment.menus.search_add_prop = menu.list(attachment.menus.add_attachment, "Search Props", {}, "Search for a prop by name")
    menu.text_input(attachment.menus.search_add_prop, "Search for Object", {"constructorsearchobject"}, "", function (query)
        clear_menu_list(attachment.menus.search_results)
        local results = search_props(query)
        for i = 1,30 do
            if results[i] then
                local model = results[i].prop
                local search_result_menu_item = menu.action(attachment.menus.search_add_prop, model, {}, "", function()
                    construct_from_plan({
                        root = attachment.root,
                        parent = attachment,
                        name = model,
                        model = model,
                    })
                end)
                menu.on_focus(search_result_menu_item, function(direction) if direction ~= 0 then add_preview({model=model}) end end)
                menu.on_blur(search_result_menu_item, function(direction) if direction ~= 0 then remove_preview() end end)
                table.insert(attachment.menus.search_results, search_result_menu_item)
            end
        end
    end)

    menu.text_input(attachment.menus.add_attachment, "Object by Name", {"constructorattachobject"},
            "Add an in-game object by exact name. To search for objects try https://gta-objects.xyz/", function (value)
                construct_from_plan({
                    root = attachment.root,
                    parent = attachment,
                    name = value,
                    model = value,
                })
            end)

    menu.text_input(attachment.menus.add_attachment, "Vehicle by Name", {"constructorattachvehicle"},
            "Add a vehicle by exact name.", function (value)
                construct_from_plan({
                    root = attachment.root,
                    parent = attachment,
                    name = value,
                    model = value,
                    type = "VEHICLE",
                })
            end)

    menu.text_input(attachment.menus.add_attachment, "Ped by Name", {"constructorattachvehicle"},
            "Add a vehicle by exact name.", function (value)
                construct_from_plan({
                    root = attachment.root,
                    parent = attachment,
                    name = value,
                    model = value,
                    type = "PED",
                })
            end)

    menu.toggle(attachment.menus.add_attachment, "Add Attachment Gun", {}, "Anything you shoot with this enabled will be added to the current construct", function(on)
        config.add_attachment_gun_active = on
        config.add_attachment_gun_recipient = attachment
    end, config.add_attachment_gun_active)

end

local function rebuild_attachment_debug_menu(attachment, parent_menu)
    if parent_menu == nil then parent_menu = attachment.root.menus.debug end
    for key, value in pairs(attachment) do
        local field_type = type(value)
        local field_value = tostring(value)
        if field_type == "table" and key == "parent" or key == "root" then
            field_value = tostring(value.handle)
            field_type = "number"
        end
        if field_type == "table" then
            local new_menu = menu.list(parent_menu, key.." ("..#value..")")
            rebuild_attachment_debug_menu(value, new_menu)
        else
            menu.readonly(parent_menu, key, field_value)
        end
    end
end

local function cleanup_constructs_handler()
    if config.deconstruct_all_spawned_constructs_on_unload then
        for _, construct in pairs(spawned_constructs) do
            delete_construct(construct)
        end
    end
end

local function rebuild_reattach_to_menu(attachment, current, path, depth)
    if current == nil then current = attachment.root end
    if path == nil then path = {} end
    if depth == nil then depth = 0 end
    depth = depth + 1
    if depth > 100 then return end
    table.insert(path, current.name)
    --util.toast("Rebuilding attachment menu "..attachment.name.." path="..inspect(path), TOAST_ALL)
    menu.action(attachment.menus.option_parent_attachment, table.concat(path, " > "), {}, "", function()
        util.toast("Reattaching "..attachment.name.." to "..current.name, TOAST_ALL)
        constructor_lib.detach_attachment(attachment)
        attachment.parent = current
        attachment.root = current.root
        constructor_lib.update_attachment(attachment)
        table.insert(current.children, attachment)
        attachment.root.menus.refresh()
        attachment.menus.focus()
    end)
    for _, child_attachment in pairs(current.children) do
        rebuild_reattach_to_menu(attachment, child_attachment, table.table_copy(path))
    end
end

menus.rebuild_attachment_menu = function(attachment)
    if attachment.menus == nil then
        attachment.menus = {}

        local parent_menu
        if attachment == attachment.parent then
            parent_menu = menus.loaded_constructs
        else
            parent_menu = attachment.parent.menus.edit_attachments
        end
        attachment.menus.main = menu.list(parent_menu, attachment.name)
        -- TODO: This causes a crash when loading vehicle?!
        --attachment.menus.children = {}
        --table.insert(attachment.parent.menus.children, attachment.menus)

        --menu.divider(attachment.menus.main, "Info")

        attachment.menus.name = menu.text_input(attachment.menus.main, "Name", { "constructorsetattachmentname"..attachment.handle}, "Set name of the attachment", function(value)
            attachment.name = value
            attachment.menus.refresh()
        end, attachment.name)

        --attachment.menus.manage = menu.list(attachment.menus.main, "Manage")

        --menu.divider(attachment.menus.main, "Position")
        attachment.menus.position = menu.list(attachment.menus.main, "Position")

        menu.divider(attachment.menus.position, "Offset")
        attachment.menus.edit_offset_x = menu.slider_float(attachment.menus.position, "X: Left / Right", { "constructoroffset"..attachment.handle.."x"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.offset.x * 100), config.edit_offset_step, function(value)
            attachment.offset.x = value / 100
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_offset_y = menu.slider_float(attachment.menus.position, "Y: Forward / Back", {"constructoroffset"..attachment.handle.."y"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.offset.y * -100), config.edit_offset_step, function(value)
            attachment.offset.y = value / -100
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_offset_z = menu.slider_float(attachment.menus.position, "Z: Up / Down", {"constructoroffset"..attachment.handle.."z"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.offset.z * -100), config.edit_offset_step, function(value)
            attachment.offset.z = value / -100
            constructor_lib.move_attachment(attachment)
        end)

        menu.divider(attachment.menus.position, "Rotation")
        attachment.menus.edit_rotation_x = menu.slider(attachment.menus.position, "X: Pitch", {"constructorrotate"..attachment.handle.."x"}, "Hold SHIFT to fine tune", -179, 180, math.floor(attachment.rotation.x), config.edit_rotation_step, function(value)
            attachment.rotation.x = value
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_rotation_y = menu.slider(attachment.menus.position, "Y: Roll", {"constructorrotate"..attachment.handle.."y"}, "Hold SHIFT to fine tune", -179, 180, math.floor(attachment.rotation.y), config.edit_rotation_step, function(value)
            attachment.rotation.y = value
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_rotation_z = menu.slider(attachment.menus.position, "Z: Yaw", {"constructorrotate"..attachment.handle.."z"}, "Hold SHIFT to fine tune", -179, 180, math.floor(attachment.rotation.z), config.edit_rotation_step, function(value)
            attachment.rotation.z = value
            constructor_lib.move_attachment(attachment)
        end)

        menu.divider(attachment.menus.position, "World Position")
        attachment.menus.edit_position_x = menu.slider_float(attachment.menus.position, "X: Left / Right", { "constructorposition"..attachment.handle.."x"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.position.x * 100), config.edit_offset_step, function(value)
            attachment.position.x = value / 100
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_position_y = menu.slider_float(attachment.menus.position, "Y: Forward / Back", {"constructorposition"..attachment.handle.."y"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.position.y * -100), config.edit_offset_step, function(value)
            attachment.position.y = value / -100
            constructor_lib.move_attachment(attachment)
        end)
        attachment.menus.edit_position_z = menu.slider_float(attachment.menus.position, "Z: Up / Down", {"constructorposition"..attachment.handle.."z"}, "Hold SHIFT to fine tune", -500000, 500000, math.floor(attachment.position.z * -100), config.edit_offset_step, function(value)
            attachment.position.z = value / -100
            constructor_lib.move_attachment(attachment)
        end)

        --menu.divider(attachment.menus.main, "Options")
        attachment.menus.options = menu.list(attachment.menus.main, "Options")
        --local light_color = {r=0}
        --menu.slider(attachment.menu, "Color: Red", {}, "", 0, 255, light_color.r, 1, function(value)
        --    -- Only seems to work locally :(
        --    OBJECT._SET_OBJECT_LIGHT_COLOR(attachment.handle, 1, light_color.r, 0, 128)
        --end)
        attachment.menus.option_visible = menu.toggle(attachment.menus.options, "Visible", {}, "Will the attachment be visible, or invisible", function(on)
            attachment.options.is_visible = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_visible)
        attachment.menus.option_collision = menu.toggle(attachment.menus.options, "Collision", {}, "Will the attachment collide with things, or pass through them", function(on)
            attachment.options.has_collision = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.has_collision)
        attachment.menus.option_invincible = menu.toggle(attachment.menus.options, "Invincible", {}, "Will the attachment be impervious to damage, or be damageable.", function(on)
            attachment.options.is_invincible = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_invincible)
        attachment.menus.option_gravity = menu.toggle(attachment.menus.options, "Gravity", {}, "Will the attachment be effected by gravity, or be weightless", function(on)
            attachment.options.has_gravity = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.has_gravity)
        attachment.menus.option_frozen = menu.toggle(attachment.menus.options, "Frozen", {}, "Will the attachment be frozen in place, or allowed to move freely", function(on)
            attachment.options.is_frozen = on
        end, attachment.options.is_frozen)
        -- Attachment


        attachment.menus.option_parent_attachment = menu.list(attachment.menus.options, "Reattach To", {}, "", function()
            rebuild_reattach_to_menu(attachment)
            menu.action(attachment.menus.option_parent_attachment, attachment.root.name, {}, "", function()
                local new_parent = attachment.root
                constructor_lib.detach_attachment(attachment)
                attachment.parent = new_parent
                attachment.root = new_parent.root
                constructor_lib.update_attachment(attachment)
            end)
            -- TODO: build attachments list

        end)
        attachment.menus.option_bone_index = menu.slider(attachment.menus.options, "Bone Index", {}, "", -1, attachment.parent.num_bones or 100, attachment.options.bone_index or 0, 1, function(value)
            attachment.options.bone_index = value
            constructor_lib.update_attachment(attachment)
        end)
        attachment.menus.option_soft_pinning = menu.toggle(attachment.menus.options, "Soft Pinning", {}, "Will the attachment detach when repaired", function(on)
            attachment.options.use_soft_pinning = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.use_soft_pinning)
        -- Lights
        attachment.menus.option_is_light_on = menu.toggle(attachment.menus.options, "Light On", {}, "If attachment is a light, it will be on and lit (many lights only work during night time).", function(on)
            attachment.options.is_light_on = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_light_on)
        attachment.menus.option_light_disabled = menu.toggle(attachment.menus.options, "Light Disabled", {}, "If attachment is a light, it will be ALWAYS off, regardless of others settings.", function(on)
            attachment.options.is_light_disabled = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_light_disabled)
        -- Proofs
        attachment.menus.option_is_bullet_proof = menu.toggle(attachment.menus.options, "Bullet Proof", {}, "If attachment is impervious to damage from bullets.", function(on)
            attachment.options.is_bullet_proof = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_bullet_proof)
        attachment.menus.option_is_fire_proof = menu.toggle(attachment.menus.options, "Fire Proof", {}, "If attachment is impervious to damage from fire.", function(on)
            attachment.options.is_fire_proof = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_fire_proof)
        attachment.menus.option_is_explosion_proof = menu.toggle(attachment.menus.options, "Explosion Proof", {}, "If attachment is impervious to damage from explosions.", function(on)
            attachment.options.is_explosion_proof = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_explosion_proof)
        attachment.menus.option_is_melee_proof = menu.toggle(attachment.menus.options, "Melee Proof", {}, "If attachment is impervious to damage from melee attacks.", function(on)
            attachment.options.is_melee_proof = on
            constructor_lib.update_attachment(attachment)
        end, attachment.options.is_melee_proof)

        attachment.menus.detach = menu.action(attachment.menus.options, "Detach", {}, "Detach attachment from construct to create a new construct", function()
            local original_parent = attachment.parent
            constructor_lib.detach_attachment(attachment)
            table.insert(spawned_constructs, attachment)
            --for _, child_menu in pairs(attachment.menus) do
            --    if type(child_menu) == "number" then
            --        menu.delete(child_menu)
            --    end
            --end
            attachment.menus = nil
            menus.rebuild_attachment_menu(attachment)
            original_parent.menus.refresh()
            attachment.menus.refresh()
            attachment.menus.focus()
            menus.refresh_loaded_constructs()
        end)

        --menu.divider(attachment.menus.main, "Attachments")
        --attachment.menus.attachments = menu.list(attachment.menus.main, "Attachments")
        attachment.menus.add_attachment = menu.list(attachment.menus.main, "Add Attachment", {}, "", function()
            menus.rebuild_add_attachments_menu(attachment)
        end)
        attachment.menus.edit_attachments = menu.list(attachment.menus.main, "Edit Attachments ("..#attachment.children..")", {}, "", function()
            menus.rebuild_attachment_menu(attachment)
        end)

        attachment.menus.clone_options = menu.list(attachment.menus.main, "Clone")
        attachment.menus.clone_in_place = menu.action(attachment.menus.clone_options, "Clone (In Place)", {}, "", function()
            local new_attachment = constructor_lib.clone_attachment(attachment)
            construct_from_plan(new_attachment)
        end)
        attachment.menus.clone_reflection_x = menu.action(attachment.menus.clone_options, "Clone Reflection: X:Left/Right", {}, "", function()
            local new_attachment = constructor_lib.clone_attachment(attachment)
            new_attachment.offset = {x=-attachment.offset.x, y=attachment.offset.y, z=attachment.offset.z}
            construct_from_plan(new_attachment)
        end)
        attachment.menus.clone_reflection_y = menu.action(attachment.menus.clone_options, "Clone Reflection: Y:Front/Back", {}, "", function()
            local new_attachment = constructor_lib.clone_attachment(attachment)
            new_attachment.offset = {x=attachment.offset.x, y=-attachment.offset.y, z=attachment.offset.z}
            construct_from_plan(new_attachment)
        end)
        attachment.menus.clone_reflection_z = menu.action(attachment.menus.clone_options, "Clone Reflection: Z:Up/Down", {}, "", function()
            local new_attachment = constructor_lib.clone_attachment(attachment)
            new_attachment.offset = {x=attachment.offset.x, y=attachment.offset.y, z=-attachment.offset.z}
            construct_from_plan(new_attachment)
        end)

        --menu.divider(attachment.menus.main, "Actions")

        attachment.menus.teleport = menu.list(attachment.menus.main, "Teleport")
        if attachment.type == "VEHICLE" then
            attachment.menus.enter_drivers_seat = menu.action(attachment.menus.teleport, "Teleport Into Vehicle", {}, "", function()
                PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), attachment.handle, -1)
            end)
        end
        attachment.menus.enter_drivers_seat = menu.action(attachment.menus.teleport, "Teleport To", {}, "", function()
            local pos = ENTITY.GET_ENTITY_COORDS(attachment.handle)
            ENTITY.SET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z + 2)
        end)

        attachment.menus.debug = menu.list(attachment.menus.main, "Debug Info")
        rebuild_attachment_debug_menu(attachment)

        attachment.menus.reconstruct_vehicle = menu.action(attachment.menus.main, "Rebuild", {}, "Delete construct (if it still exists), then recreate a new one from scratch.", function()
            local construct_plan = constructor_lib.clone_attachment(attachment)
            delete_construct(attachment)
            construct_from_plan(construct_plan)
        end)
        attachment.menus.save = menu.action(attachment.menus.main, "Save", {}, "Save this construct to disk so it can be loaded and shared", function()
            save_vehicle(attachment)
        end)
        attachment.menus.delete = menu.action(attachment.menus.main, "Delete", {}, "Delete construct and all attachments. Cannot be reconstructed unless saved.", function()
            if #attachment.children > 0 then
                menu.show_warning(attachment.menus.main, CLICK_COMMAND, "Are you sure you want to delete this construct? "..#attachment.children.." children will also be deleted.", function()
                    delete_construct(attachment)
                end)
            else
                delete_construct(attachment)
            end
        end)


        for _, menu_handle in pairs(attachment.menus) do
            menu.on_focus(menu_handle, function(direction) if direction ~= 0 then attachment.is_editing = true end end)
            menu.on_blur(menu_handle, function(direction) if direction ~= 0 then attachment.is_editing = false end end)
        end

        attachment.menus.refresh = function(updated_attachment)
            menu.set_menu_name(attachment.menus.main, attachment.name)
            menu.set_menu_name(attachment.menus.edit_attachments, "Edit Attachments ("..#attachment.children..")")
            rebuild_attachment_debug_menu(attachment)
            menus.rebuild_attachment_menu(attachment)
            menus.refresh_loaded_constructs()
            if updated_attachment ~= nil and updated_attachment.menus ~= nil then
                util.toast("Refreshing menu. updated attachment "..updated_attachment.name, TOAST_ALL)
                menu.focus(updated_attachment.menus.name)
            end
        end
        attachment.menus.focus = function()
            pcall(menu.focus, attachment.menus.name)
        end

        for _, child_attachment in pairs(attachment.children) do
            menus.rebuild_attachment_menu(child_attachment)
        end

    else
        ---- Validate attachment is still a child
        --local found = false
        --for _, child_attachment in pairs(attachment.parent) do
        --    if child_attachment == attachment then
        --        found = true
        --    end
        --end
        --if not found then
        --    -- Delete menus
        --    for _, child_menu in pairs(attachment.parent)
        --end

    end
end

---
--- Static Menus
---

menus.create_new_construct = menu.list(menu.my_root(), "Create New Construct")

menu.action(menus.create_new_construct, "Vehicle From Current", { "constructcreatefromvehicle" }, "Create a new construct based on current (or last in) vehicle", function()
    local vehicle = entities.get_user_vehicle_as_handle()
    if vehicle == 0 then
        util.toast("Error: You must be (or recently been) in a vehicle to create a construct from it")
        return
    end
    local construct = create_construct_from_vehicle(vehicle)
    if construct then
        menus.rebuild_attachment_menu(construct)
        construct.menus.refresh()
        menu.focus(construct.menus.name)
    end
end)

menu.text_input(menus.create_new_construct, "Vehicle From Name", { "constructcreatefromvehiclename"}, "Create a new construct from a vehicle name", function(value)
    local construct_plan = {
        model = value,
        type="VEHICLE",
    }
    construct_plan.root = construct_plan
    construct_plan.parent = construct_plan
    construct_from_plan(construct_plan)
end)

menu.action(menus.create_new_construct, "Structure", { "constructcreatestructure"}, "Create a new stationary construct", function()
    local construct_plan = {
        model = "prop_air_conelight",
        options = {
            is_frozen = true,
            has_collision = false,
            alpha = 205,
        },
    }
    construct_plan.root = construct_plan
    construct_plan.parent = construct_plan
    construct_from_plan(construct_plan)
end)

menu.text_input(menus.create_new_construct, "Structure From Object", { "constructcreatestructurefromobjectname"}, "Create a new stationary construct from an object name", function(value)
    local construct_plan = {
        model = value,
    }
    construct_plan.root = construct_plan
    construct_plan.parent = construct_plan
    construct_from_plan(construct_plan)
end)

---
--- Saved Constructs Menu
---

local load_constructs_root_menu_file
menus.load_construct = menu.list(menu.my_root(), "Load Construct", {}, "Load a previously saved or shared construct into the world", function()
    menus.rebuild_load_construct_menu()
end)
load_constructs_root_menu_file = {menu=menus.load_construct, name="Loaded Constructs Menu", menus={}}

menu.hyperlink(menus.load_construct, "Open Constructs Folder", "file:///"..CONSTRUCTS_DIR, "Open constructs folder. Share your creations or add new creations here.")

menus.rebuild_load_construct_menu = function(path, parent_construct_plan_file)
    if path == nil then path = "" end
    if parent_construct_plan_file == nil then parent_construct_plan_file = load_constructs_root_menu_file end
    if parent_construct_plan_file.menus == nil then parent_construct_plan_file.menus = {} end
    for _, construct_plan_menu in pairs(parent_construct_plan_file.menus) do
        pcall(menu.delete, construct_plan_menu)
    end
    for _, construct_plan_file in pairs(load_construct_plans_files_from_dir(CONSTRUCTS_DIR..path)) do
        if construct_plan_file.is_directory then
            construct_plan_file.menu = menu.list(parent_construct_plan_file.menu, construct_plan_file.name or "unknown", {}, "", function()
                menus.rebuild_load_construct_menu(path.."/"..construct_plan_file.filename, construct_plan_file)
            end)
        else
            construct_plan_file.menu = menu.action(parent_construct_plan_file.menu, construct_plan_file.name, {}, "", function()
                remove_preview()
                local construct_plan = load_construct_plan_file(construct_plan_file)
                if construct_plan then
                    construct_plan.root = construct_plan
                    construct_plan.parent = construct_plan
                    construct_from_plan(construct_plan)
                end
            end)
            menu.on_focus(construct_plan_file.menu, function(direction) if direction ~= 0 then add_preview(load_construct_plan_file(construct_plan_file)) end end)
            menu.on_blur(construct_plan_file.menu, function(direction) if direction ~= 0 then remove_preview() end end)
        end
        table.insert(parent_construct_plan_file.menus, construct_plan_file.menu)
    end
end

menus.loaded_constructs = menu.list(menu.my_root(), "Loaded Constructs ("..#spawned_constructs..")", {}, "", function()

end)

menus.refresh_loaded_constructs = function()
    menu.set_menu_name(menus.loaded_constructs, "Loaded Constructs ("..#spawned_constructs..")")
end

local options_menu = menu.list(menu.my_root(), "Options")

menu.divider(options_menu, "Global Configs")

menu.slider(options_menu, "Edit Offset Step", {}, "The amount of change each time you edit an attachment offset (hold SHIFT or L1 for fine tuning)", 1, 50, config.edit_offset_step, 1, function(value)
    config.edit_offset_step = value
end)
menu.slider(options_menu, "Edit Rotation Step", {}, "The amount of change each time you edit an attachment rotation (hold SHIFT or L1 for fine tuning)", 1, 30, config.edit_rotation_step, 1, function(value)
    config.edit_rotation_step = value
end)
menu.toggle(options_menu, "Drive Spawned Vehicles", {}, "When spawning vehicles, automatically place you into the drivers seat.", function(on)
    config.drive_spawned_vehicles = on
end, config.drive_spawned_vehicles)
menu.toggle(options_menu, "Show Previews", {}, "Show previews when adding attachments", function(on)
    config.show_previews = on
end, config.show_previews)
menu.toggle(options_menu, "Deconstruct All on Unload", {}, "Deconstruct all spawned constructs when unloading Constructor", function(on)
    config.deconstruct_all_spawned_constructs_on_unload = on
end, config.deconstruct_all_spawned_constructs_on_unload)


local script_meta_menu = menu.list(menu.my_root(), "Script Meta")
menu.divider(script_meta_menu, "Constructor")
menu.readonly(script_meta_menu, "Version", SCRIPT_VERSION)
menu.readonly(script_meta_menu, "Constructor Lib Version", constructor_lib.LIB_VERSION)
menu.list_select(script_meta_menu, "Release Branch", {}, "Switch from main to dev to get cutting edge updates, but also potentially more bugs.", AUTO_UPDATE_BRANCHES, SELECTED_BRANCH_INDEX, function(index, menu_name, previous_option, click_type)
    if click_type ~= 0 then return end
    auto_update_branch(AUTO_UPDATE_BRANCHES[index][1])
end)
menu.hyperlink(script_meta_menu, "Github Source", "https://github.com/hexarobi/stand-lua-constructor", "View source files on Github")
menu.hyperlink(script_meta_menu, "Discord", "https://discord.gg/RF4N7cKz", "Open Discord Server")
menu.divider(script_meta_menu, "Credits")
menu.readonly(script_meta_menu, "Jackz", "Much of Constructor is based on code from Jackz Vehicle Builder and wouldn't have been possible without this foundation")
menu.readonly(script_meta_menu, "BigTuna", "Testing, Suggestions and Support")

local function constructor_tick()
    aim_info_tick()
    update_preview_tick()
    sensitivity_modifier_check_tick()
    frozen_attachment_tick()
    draw_editing_attachment_bounding_box_tick()
end
util.create_tick_handler(constructor_tick)

util.create_tick_handler(function()
    ped_animation_tick()
    util.yield(10000)
    return true
end)

util.on_stop(cleanup_constructs_handler)

util.create_tick_handler(function()
    return true
end)

