local town = require "zomboid:town"

local countryside = {
    CELL = 64,
    LOT = 52,
    MARGIN = 6,
    RURAL = 300,
    LANE_RAMP = 24,
    LOT_RAMP = 40,
    REACH = 10,
}

local CELL, LOT, MARGIN = countryside.CELL, countryside.LOT, countryside.MARGIN
local hash = town.hash
local floor = math.floor

local function highway_z(wx)
    return town.highway_z and town.highway_z(wx) or 0
end

-- lanes run north-south along x = i * CELL for even i; columns near the river have none
local function lane_ok(i)
    return i % 2 == 0 and math.abs(i * CELL - 50) > 70
end

local function clear_of_town(x0, z0, x1, z1)
    local fe = town.FLAT_EXTENT + 16
    if not (x1 < -fe or x0 > fe or z1 < -fe or z0 > fe) then
        return false
    end
    if town.flat_dist then
        for _, p in ipairs({{x0, z0}, {x1, z0}, {x0, z1}, {x1, z1}, {(x0 + x1) / 2, (z0 + z1) / 2}}) do
            if town.flat_dist(p[1], p[2]) < 16 then
                return false
            end
        end
    end
    return true
end

local picks = {}

local function pick(zone, r)
    local list = picks[zone]
    if list == nil then
        list = {total = 0}
        for _, def in ipairs(town.building_defs()) do
            for _, z in ipairs(def.zones or {}) do
                if z == zone then
                    table.insert(list, def)
                    list.total = list.total + (def.weight or 1)
                end
            end
        end
        picks[zone] = list
    end
    r = r * list.total
    for _, def in ipairs(list) do
        r = r - (def.weight or 1)
        if r < 0 then
            return def
        end
    end
    return nil
end

local lots = {}

-- the lot of countryside cell (i, j) or nil; buildings face the lane: west (rot 1) in even columns, east (rot 3) in odd
function countryside.lot(i, j)
    local key = i * 65536 + j
    local p = lots[key]
    if p ~= nil then
        return p or nil
    end
    lots[key] = false
    local lx0, lz0 = i * CELL + MARGIN, j * CELL + MARGIN
    local lx1, lz1 = lx0 + LOT - 1, lz0 + LOT - 1
    local cx, cz = lx0 + LOT / 2, lz0 + LOT / 2
    local east = i % 2 ~= 0
    local lane_x = (east and i + 1 or i) * CELL
    local zone = math.max(math.abs(cx), math.abs(cz)) - town.FLAT_EXTENT < countryside.RURAL and "rural" or "forest"
    if not lane_ok(lane_x / CELL) or hash(i, j, 71) >= (zone == "rural" and 0.35 or 0.1)
        or math.abs(j - floor(highway_z(lane_x) / CELL)) > countryside.REACH
        or not clear_of_town(math.min(lx0, lane_x) - 4, lz0 - 8, math.max(lx1, lane_x) + 4, lz1 + 8)
        or require("zomboid:nature").river_dist(cx, cz) < 70 then
        return nil
    end
    local def = pick(zone, hash(i, j, 72))
    if def == nil then
        return nil
    end
    p = {kind = def.kind, def = def, cx = i, cz = j, zone = zone, rot = east and 3 or 1, lot_w = LOT, lot_d = LOT}
    def.plan(p, function(n) return hash(i, j, 100 + n) end)
    p.ox = p.ox or floor((LOT - p.w) / 2)
    p.oz = p.oz or 3
    p.door = p.door or floor(p.w / 2)
    if east then
        p.x1 = lx1 - p.oz
        p.z0 = lz0 + p.ox
        p.x0 = p.x1 - p.d + 1
        p.z1 = p.z0 + p.w - 1
        p.spur_z = p.z0 + p.door
    else
        p.x0 = lx0 + p.oz
        p.z1 = lz1 - p.ox
        p.x1 = p.x0 + p.d - 1
        p.z0 = p.z1 - p.w + 1
        p.spur_z = p.z1 - p.door
    end
    p.lx0, p.lz0, p.lx1, p.lz1 = lx0, lz0, lx1, lz1
    p.lane_x = lane_x
    lots[key] = p
    return p
end

local lanes = {}

-- z extent {north, south} of the lane along x = i * CELL, from the highway to the farthest lot
function countryside.lane(i)
    local l = lanes[i]
    if l ~= nil then
        return l or nil
    end
    lanes[i] = false
    if not lane_ok(i) then
        return nil
    end
    local hz = highway_z(i * CELL)
    local n, s = hz, hz
    local j0 = floor(hz / CELL)
    for j = j0 - countryside.REACH, j0 + countryside.REACH do
        for di = -1, 0 do
            local p = countryside.lot(i + di, j)
            if p then
                n, s = math.min(n, p.spur_z), math.max(s, p.spur_z)
            end
        end
    end
    if n == s then
        return nil
    end
    l = {n, s}
    lanes[i] = l
    return l
end

local function lot_at(wx, wz)
    local p = countryside.lot(floor(wx / CELL), floor(wz / CELL))
    if p and wx >= p.lx0 and wx <= p.lx1 and wz >= p.lz0 and wz <= p.lz1 then
        return p
    end
    return nil
end

local function road_at(wx, wz)
    local i = floor((wx + 1) / CELL)
    local lx = i * CELL
    if math.abs(wx - lx) <= 1 then
        local l = countryside.lane(i)
        if l and wz >= l[1] - 1 and wz <= l[2] + 1 then
            return true
        end
    end
    local p = countryside.lot(floor(wx / CELL), floor(wz / CELL))
    return p ~= nil and math.abs(wz - p.spur_z) <= 1
        and (p.rot == 1 and wx >= p.lane_x and wx < p.x0 or p.rot == 3 and wx > p.x1 and wx <= p.lane_x)
end

function countryside.building_at(wx, wz)
    local p = lot_at(wx, wz)
    if p == nil then
        return nil
    end
    local hx, hz = town.to_local(p, wx, wz)
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        return p.kind, p, hx, hz
    end
    return nil
end

-- building entries carry local rotations; turn them with the lot
local function turn(out, from, rot)
    for k = from, #out do
        out[k][3] = (out[k][3] + rot) % 4
    end
end

-- the countryside part of town.column: lots and dirt roads, nil for wild land
function countryside.column(wx, wz, out)
    local p = lot_at(wx, wz)
    if p then
        local hx, hz = town.to_local(p, wx, wz)
        local from = out and #out + 1
        if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
            if out then
                p.def.column(p, hx, hz, out)
                turn(out, from, p.rot)
            end
            return "building"
        end
        local kind = p.def.lot and p.def.lot(p, hx, hz, out)
        if kind then
            if out then
                turn(out, from, p.rot)
            end
            return kind
        end
        if road_at(wx, wz) then
            if out then
                table.insert(out, {0, "zomboid:nature_dirt_path", 0})
                table.insert(out, {1, "core:struct_air", 0})
            end
            return "dirt_road"
        end
        return "yard"
    end
    if road_at(wx, wz) then
        if out then
            table.insert(out, {0, "zomboid:nature_dirt_path", 0})
            table.insert(out, {1, "core:struct_air", 0})
            table.insert(out, {2, "core:struct_air", 0})
        end
        return "dirt_road"
    end
    return nil
end

-- trees and rocks keep two blocks off dirt roads (lots and the roads themselves are town.column kinds)
function countryside.near_road(wx, wz)
    return road_at(wx + 2, wz) or road_at(wx - 2, wz) or road_at(wx, wz + 2) or road_at(wx, wz - 2)
end

-- flat pads {cx, cz, half_w, half_d, ramp} touching the area; lots_only for biome shaping
function countryside.pads(x0, z0, x1, z1, lots_only)
    local out = {}
    local reach = countryside.LOT_RAMP
    for i = floor((x0 - reach) / CELL), floor((x1 + reach) / CELL) do
        for j = floor((z0 - reach) / CELL), floor((z1 + reach) / CELL) do
            local p = countryside.lot(i, j)
            if p then
                local px0, px1 = math.min(p.lx0, p.lane_x - 2), math.max(p.lx1, p.lane_x + 2)
                table.insert(out, {(px0 + px1) / 2, (p.lz0 + p.lz1) / 2, (px1 - px0) / 2, LOT / 2,
                    countryside.LOT_RAMP})
            end
        end
        local l = not lots_only and countryside.lane(i)
        if l and l[2] >= z0 - reach and l[1] <= z1 + reach then
            table.insert(out, {i * CELL, (l[1] + l[2]) / 2, 2, (l[2] - l[1]) / 2 + 2, countryside.LANE_RAMP})
        end
    end
    return out
end

return countryside
