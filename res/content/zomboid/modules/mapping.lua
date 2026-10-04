local town = require "zomboid:town"
local survival = require "zomboid:survival"
local inv = require "zomboid:inv"

local mapping = {
    TILE = 8,
    RADIUS = 28,
    ORIGIN = -128,
    SIZE = 256,
}

local COLORS = {
    road = {58, 58, 62},
    sidewalk = {150, 150, 145},
    path = {150, 150, 145},
    lawn = {92, 140, 70},
    park = {70, 125, 60},
    wild = {48, 88, 46},
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
    return COLORS[kind or "wild"]
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

function mapping.draw(canvas, pid, scale)
    canvas:clear(20, 18, 14, 255)
    local t = mapping.TILE
    for tx = 0, mapping.SIZE / t - 1 do
        for tz = 0, mapping.SIZE / t - 1 do
            local wx0, wz0 = mapping.ORIGIN + tx * t, mapping.ORIGIN + tz * t
            if mapping.is_explored(pid, wx0, wz0) then
                for dx = 0, t - 1 do
                    for dz = 0, t - 1 do
                        local c = mapping.color(wx0 + dx, wz0 + dz)
                        canvas:rect((tx * t + dx) * scale, (tz * t + dz) * scale, scale, scale, c[1], c[2], c[3], 255)
                    end
                end
            end
        end
    end
    local x, _, z = player.get_pos(pid)
    local px, pz = (x - mapping.ORIGIN) * scale, (z - mapping.ORIGIN) * scale
    canvas:rect(math.floor(px) - 3, math.floor(pz) - 3, 7, 7, 255, 40, 40, 255)
    canvas:update()
end

return mapping
