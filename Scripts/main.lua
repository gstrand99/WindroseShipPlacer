-- WindroseShipPlacer - dev UE4SS mod: snap nearest ship to dock/wharf berth offsets.
--
-- Install: copy this folder to ue4ss\Mods\WindroseShipPlacer\ and enable in mods.txt.
--
-- KEYBIND CONFIG (edit below, restart game):
--   KEY_BERTH + no modifier     = front berth, dock yaw
--   KEY_BERTH + MOD_SIDE_PLUS   = side berth, dock yaw + 90
--   KEY_BERTH + MOD_SIDE_MINUS  = side berth, dock yaw - 90
-- UE4SS keys: Key.F6, Key.F7, Key.F8, ...  Modifiers: ModifierKey.SHIFT, ModifierKey.ALT, ModifierKey.CONTROL

local KEY_BERTH = Key.F7
local MOD_SIDE_PLUS = { ModifierKey.SHIFT }
local MOD_SIDE_MINUS = { ModifierKey.ALT }

local MOD = "[WindroseShipPlacer]"

local BERTH_FORWARD = -2625.0
local BERTH_RIGHT = 50.0
local BERTH_UP = -98.0

local SIDE_FORWARD = -1200.0
local SIDE_RIGHT = -1200.0
local SIDE_UP = -98.0

local MIN_SHIP_DIST_SQ = 10000.0

local ship_scan_classes = {
    "R5ShipPawnBase",
    "BP_Ship_Brig_Default_C",
    "BP_Ship_Frigate_Default_C",
    "BP_Ship_Ketch_Default_C",
    "BP_Ship_Ketch_Moored_C",
    "BP_Ship_ShallowBoat_Default_C",
}

local dock_scan_classes = {
    "R5BuildingBlock_ShipDock",
    "BP_ShipDock_02_C",
    "BP_ShipDock_01_C",
}

local function log(message)
    print(string.format("%s %s\n", MOD, tostring(message)))
end

local function unwrap(value)
    if type(value) == "userdata" and value.get ~= nil then
        local ok, unwrapped = pcall(function()
            return value:get()
        end)
        if ok and unwrapped ~= nil then
            return unwrapped
        end
    end
    return value
end

local function safe_call(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return nil
end

local function actor_address(value)
    local obj = unwrap(value)
    if obj == nil or type(obj) ~= "userdata" then
        return tostring(obj)
    end
    return safe_call(function()
        return string.format("0x%X", obj:GetAddress())
    end) or tostring(obj)
end

local function get_actor_location_value(value)
    local actor = unwrap(value)
    if actor == nil or type(actor) ~= "userdata" then
        return nil
    end
    return safe_call(function()
        return actor:K2_GetActorLocation()
    end)
end

local function get_actor_rotation_value(value)
    local actor = unwrap(value)
    if actor == nil or type(actor) ~= "userdata" then
        return nil
    end
    return safe_call(function()
        return actor:K2_GetActorRotation()
    end)
end

local function distance_sq(a, b)
    if a == nil or b == nil then
        return nil
    end
    local dx = a.X - b.X
    local dy = a.Y - b.Y
    local dz = a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

local function yaw_basis(yaw_degrees)
    local radians = math.rad(yaw_degrees or 0.0)
    return {
        x = math.cos(radians),
        y = math.sin(radians),
    }, {
        x = -math.sin(radians),
        y = math.cos(radians),
    }
end

local function add_local_offset(origin, yaw_degrees, forward_offset, right_offset, up_offset)
    if origin == nil then
        return nil
    end
    local forward, right = yaw_basis(yaw_degrees)
    return {
        X = origin.X + forward.x * forward_offset + right.x * right_offset,
        Y = origin.Y + forward.y * forward_offset + right.y * right_offset,
        Z = origin.Z + (up_offset or 0.0),
    }
end

local function make_vector(x, y, z)
    local ok, value = pcall(function()
        return FVector(x, y, z)
    end)
    if ok then
        return value
    end
    return { X = x, Y = y, Z = z }
end

local function make_rotator(pitch, yaw, roll)
    local ok, value = pcall(function()
        return FRotator(pitch, yaw, roll)
    end)
    if ok then
        return value
    end
    return { Pitch = pitch, Yaw = yaw, Roll = roll }
end

local function resolve_snap_yaw(facing_yaw_mode, dock_yaw)
    if facing_yaw_mode == "dock+90" then
        return dock_yaw + 90.0
    end
    if facing_yaw_mode == "dock-90" then
        return dock_yaw - 90.0
    end
    return dock_yaw
end

local function find_local_player_context()
    local result = {
        controller = nil,
        pawn = nil,
        pawn_location = nil,
    }

    local controllers = safe_call(function()
        return FindAllOf("PlayerController") or FindAllOf("Controller")
    end)

    if controllers ~= nil then
        for _, controller_value in ipairs(controllers) do
            local controller = unwrap(controller_value)
            if controller ~= nil and type(controller) == "userdata" then
                local is_valid = safe_call(function()
                    return controller:IsValid()
                end)
                local is_local = safe_call(function()
                    return controller:IsLocalPlayerController()
                end)
                if is_valid == true and is_local == true then
                    result.controller = controller
                    result.pawn = safe_call(function()
                        return controller.Pawn
                    end)
                    if type(result.pawn) ~= "userdata" then
                        result.pawn = nil
                    end
                    result.pawn_location = get_actor_location_value(result.pawn)
                    return result
                end
            end
        end
    end

    local pawns = safe_call(function()
        return FindAllOf("R5PlayerCharacter") or FindAllOf("BP_R5Character_C")
    end)

    if pawns ~= nil then
        for _, pawn_value in ipairs(pawns) do
            local pawn = unwrap(pawn_value)
            if pawn ~= nil and type(pawn) == "userdata" then
                local is_valid = safe_call(function()
                    return pawn:IsValid()
                end)
                if is_valid == true then
                    result.pawn = pawn
                    result.pawn_location = get_actor_location_value(pawn)
                    return result
                end
            end
        end
    end

    return result
end

local function find_nearest_dock(player_location)
    local best = nil
    local seen = {}

    for _, class_name in ipairs(dock_scan_classes) do
        local ok, result = pcall(function()
            return FindAllOf(class_name)
        end)

        if ok and result ~= nil then
            for _, dock_value in ipairs(result) do
                local dock = unwrap(dock_value)
                if dock ~= nil and type(dock) == "userdata" then
                    local valid = safe_call(function()
                        return dock:IsValid()
                    end)
                    if valid == true then
                        local addr = actor_address(dock)
                        if seen[addr] == nil then
                            seen[addr] = true
                            local loc = get_actor_location_value(dock)
                            local dist = distance_sq(player_location, loc)
                            if best == nil or (dist ~= nil and (best.distance == nil or dist < best.distance)) then
                                best = {
                                    class_name = class_name,
                                    dock = dock,
                                    location = loc,
                                    rotation = get_actor_rotation_value(dock),
                                    distance = dist,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

local function find_nearest_visible_ship(origin)
    if origin == nil then
        return nil
    end

    local best = nil
    local seen = {}

    for _, class_name in ipairs(ship_scan_classes) do
        local ok, result = pcall(function()
            return FindAllOf(class_name)
        end)

        if ok and result ~= nil then
            for _, ship_value in ipairs(result) do
                local ship = unwrap(ship_value)
                if ship ~= nil and type(ship) == "userdata" then
                    local valid = safe_call(function()
                        return ship:IsValid()
                    end)
                    if valid == true then
                        local addr = actor_address(ship)
                        if seen[addr] == nil then
                            seen[addr] = true
                            local loc = get_actor_location_value(ship)
                            local dist = distance_sq(origin, loc)
                            if dist ~= nil and dist > MIN_SHIP_DIST_SQ then
                                if best == nil or dist < best.distance then
                                    best = {
                                        class_name = class_name,
                                        ship = ship,
                                        location = loc,
                                        rotation = get_actor_rotation_value(ship),
                                        distance = dist,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

local function snap_nearest_ship_to_berth(forward_offset, right_offset, up_offset, facing_yaw_mode)
    local player = find_local_player_context()
    if player.pawn == nil then
        log("No local player pawn.")
        return
    end

    local nearest_dock = find_nearest_dock(player.pawn_location)
    if nearest_dock == nil then
        log("No dock found near player.")
        return
    end

    local dock_loc = nearest_dock.location
    local dock_rot = nearest_dock.rotation
    local dock_yaw = 0.0
    if dock_rot ~= nil then
        dock_yaw = dock_rot.Yaw
    end

    local nearest_ship = find_nearest_visible_ship(dock_loc)
    if nearest_ship == nil then
        log("No visible ship found near dock (deploy ship first).")
        return
    end

    local snap_yaw = resolve_snap_yaw(facing_yaw_mode, dock_yaw)
    local target = add_local_offset(dock_loc, dock_yaw, forward_offset, right_offset, up_offset)
    if target == nil then
        log("Failed to compute berth position.")
        return
    end

    local target_vector = make_vector(target.X, target.Y, target.Z)
    local target_rotator = make_rotator(0.0, snap_yaw, 0.0)
    local ship = nearest_ship.ship

    safe_call(function()
        return ship:K2_SetActorLocationAndRotation(target_vector, target_rotator, false, {}, true)
    end)
end

local function snap_in_game_thread(forward_offset, right_offset, up_offset, facing_yaw_mode)
    local ok, err = pcall(function()
        ExecuteInGameThread(function()
            snap_nearest_ship_to_berth(forward_offset, right_offset, up_offset, facing_yaw_mode)
        end)
    end)
    if not ok then
        log("Snap schedule failed: " .. tostring(err))
        snap_nearest_ship_to_berth(forward_offset, right_offset, up_offset, facing_yaw_mode)
    end
end

local function bind_snap(label, key, modifiers, forward_offset, right_offset, up_offset, facing_yaw_mode)
    local ok, err = pcall(function()
        local handler = function()
            snap_in_game_thread(forward_offset, right_offset, up_offset, facing_yaw_mode)
        end
        if modifiers ~= nil then
            RegisterKeyBind(key, modifiers, handler)
        else
            RegisterKeyBind(key, handler)
        end
    end)
    if ok then
        log("Registered keybind: " .. label)
    else
        log("FAILED keybind " .. label .. ": " .. tostring(err))
    end
end

log("Loaded. Dock berth snap on " .. tostring(KEY_BERTH) .. " (+ modifiers for side).")

bind_snap("front dock-yaw", KEY_BERTH, nil, BERTH_FORWARD, BERTH_RIGHT, BERTH_UP, "dock")
bind_snap("side dock+90", KEY_BERTH, MOD_SIDE_PLUS, SIDE_FORWARD, SIDE_RIGHT, SIDE_UP, "dock+90")
bind_snap("side dock-90", KEY_BERTH, MOD_SIDE_MINUS, SIDE_FORWARD, SIDE_RIGHT, SIDE_UP, "dock-90")
