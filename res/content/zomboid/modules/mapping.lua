local town = require "zomboid:town"
local nature = require "zomboid:nature"
local survival = require "zomboid:survival"
local inv = require "zomboid:inv"

local mapping = {
    TILE = 8,
    RADIUS = 28,
    SIZE = 1024,
    STEP = 2,
}
local B = town.BOUNDS
mapping.ORIGIN_X = math.floor(((B[1] + B[3]) / 2 - mapping.SIZE / 2) / mapping.TILE) * mapping.TILE
mapping.ORIGIN_Z = math.floor(((B[2] + B[4]) / 2 - mapping.SIZE / 2) / mapping.TILE) * mapping.TILE

local COLORS = {
    road = {58, 58, 62},
    sidewalk = {150, 150, 145},
    path = {150, 150, 145},
    lawn = {92, 140, 70},
    park = {70, 125, 60},
    wild = {48, 88, 46},
    plaza = {190, 180, 160},
    river = {50, 100, 190},
    bridge = {120, 100, 80},
    yard = {104, 132, 66},
    dirt_road = {140, 110, 70},
}

local ZONE_LAWN = {
    industrial = {125, 120, 100},
    downtown = {120, 140, 100},
    village = {120, 160, 80},
    outskirts = {80, 125, 60},
}
mapping.COLORS = COLORS

local tick = 0

local function tile_key(tx, tz)
    return tx .. ":" .. tz
end

function mapping.explore(pid)
    local state = survival.get(pid)
    state.explored = state.explored or {}
    local x, _, z = player.get_pos(pid)
    local t = mapping.TILE
    local r = math.ceil(mapping.RADIUS / t)
    local cx, cz = math.floor(x / t), math.floor(z / t)
    for tx = cx - r, cx + r do
        for tz = cz - r, cz + r do
            if (tx - cx) ^ 2 + (tz - cz) ^ 2 <= r * r then
                state.explored[tile_key(tx, tz)] = true
            end
        end
    end
end

function mapping.is_explored(pid, wx, wz)
    local explored = survival.get(pid).explored
    return explored ~= nil and explored[tile_key(math.floor(wx / mapping.TILE), math.floor(wz / mapping.TILE))] == true
end

function mapping.has_map(pid)
    return inv.count(player.get_inventory(pid), "zomboid:map") > 0
end

function mapping.color(wx, wz)
    local kind = town.column(wx, wz)
    if kind == "building" then
        local _, p = town.building_at(wx, wz)
        return p.def.color
    end
    if kind == "lawn" or kind == "park" then
        local cx, cz = town.cell_at(wx, wz)
        local tint = cx and ZONE_LAWN[town.zone(cx, cz)]
        if tint then
            return tint
        end
    end
    if kind == nil then
        return nature.map_color(wx, wz)
    end
    return COLORS[kind] or COLORS.lawn
end

function mapping.tick()
    tick = tick + 1
    if tick % 20 ~= 0 then
        return
    end
    for _, pid in ipairs(player.get_all()) do
        if not survival.get(pid).dead then
            mapping.explore(pid)
        end
    end
end

function mapping.draw(canvas, pid)
    canvas:clear(20, 18, 14, 255)
    local t, step = mapping.TILE, mapping.STEP
    local px_tile = t / step
    for tx = 0, mapping.SIZE / t - 1 do
        for tz = 0, mapping.SIZE / t - 1 do
            local wx0, wz0 = mapping.ORIGIN_X + tx * t, mapping.ORIGIN_Z + tz * t
            if mapping.is_explored(pid, wx0, wz0) then
                for dx = 0, px_tile - 1 do
                    for dz = 0, px_tile - 1 do
                        local c = mapping.color(wx0 + dx * step, wz0 + dz * step)
                        canvas:set(tx * px_tile + dx, tz * px_tile + dz, c[1], c[2], c[3], 255)
                    end
                end
            end
        end
    end
    local x, _, z = player.get_pos(pid)
    local px, pz = (x - mapping.ORIGIN_X) / step, (z - mapping.ORIGIN_Z) / step
    canvas:rect(math.floor(px) - 2, math.floor(pz) - 2, 5, 5, 255, 40, 40, 255)
    canvas:update()
end

return mapping
