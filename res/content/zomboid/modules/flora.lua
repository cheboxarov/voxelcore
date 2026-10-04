local town = require "zomboid:town"
local nature = require "zomboid:nature"
local countryside = require "zomboid:countryside"

local flora = {}

local hash = town.hash
local SEA = nature.SEA_LEVEL
local CELL = 4
local ids = {}

local function put(out, name, x, y, z, rot)
    local id = ids[name]
    if id == nil then
        id = block.index(name)
        ids[name] = id
    end
    out[#out + 1] = {":block", id, {x, y, z}, rot or 0, 1}
end

local function disc(out, name, x, y, z, r, skip_center, salt)
    local lim = r * r + r * 0.8
    for i = -r, r do
        for j = -r, r do
            local d = i * i + j * j
            if d <= lim and not (skip_center and i == 0 and j == 0)
                and (d < r * r or hash(x + i, z + j, y + salt) < 0.7) then
                put(out, name, x + i, y, z + j)
            end
        end
    end
end

local function spruce(out, x, y, z, r)
    local h = 7 + math.floor(r * 6)
    for dy = 0, h - 1 do
        put(out, "zomboid:nature_spruce_log", x, y + dy, z)
    end
    for dy = 2, h + 1 do
        local t = h + 1 - dy
        local radius = math.min(3, math.floor(t * 0.45))
        if t % 2 == 1 and radius > 0 then
            radius = radius - 1
        end
        disc(out, "zomboid:nature_spruce_leaves", x, y + dy, z, radius, dy < h, 3)
    end
end

local function birch(out, x, y, z, r)
    local h = 6 + math.floor(r * 4)
    for dy = 0, h - 1 do
        put(out, "zomboid:nature_birch_log", x, y + dy, z)
    end
    for dy = h - 3, h + 1 do
        local radius = (dy == h - 3 or dy == h) and 1 or (dy == h + 1 and 0 or 2)
        disc(out, "zomboid:nature_birch_leaves", x, y + dy, z, radius, dy < h, 5)
    end
end

local function dead_tree(out, x, y, z, r)
    local h = 4 + math.floor(r * 3)
    for dy = 0, h - 1 do
        put(out, "zomboid:nature_spruce_log", x, y + dy, z)
    end
    local side = math.floor(r * 40) % 4
    local dx, dz = ({1, 0, -1, 0})[side + 1], ({0, 1, 0, -1})[side + 1]
    put(out, "zomboid:nature_log", x + dx, y + h - 2, z + dz, side % 2)
    put(out, "zomboid:nature_log", x - dz, y + h - 1, z + dx, (side + 1) % 2)
end

local function boulder(out, x, y, z, r, big)
    local stone = r < 0.5 and "base:stone" or "zomboid:nature_mossy_stone"
    local s = big and 2 or 1
    for i = 0, s do
        for j = 0, s do
            local top = (big and (i == 1 or j == 1)) and 2 or 1
            if hash(x + i, z + j, 31) < 0.85 or (i == 0 and j == 0) then
                for dy = 0, top do
                    put(out, stone, x + i, y + dy, z + j)
                end
            end
        end
    end
end

local function outcrop(out, x, y, z, r)
    local h = 2 + math.floor(r * 4)
    for dy = 0, h do
        put(out, "base:stone", x, y + dy, z)
        if dy < h - 1 then
            put(out, "base:stone", x + 1, y + dy, z)
            put(out, "base:stone", x, y + dy, z + 1)
        end
    end
end

local function bush(out, x, y, z, r)
    put(out, "zomboid:nature_bush", x, y, z)
    if r > 0.5 then
        put(out, "zomboid:nature_bush", x + (r > 0.75 and 1 or 0), y, z + (r > 0.75 and 0 or 1))
    end
end

-- {density per 4x4 cell, {builder, weight}...}
local MIX = {
    forest = {0.62, {spruce, 0.82}, {birch, 0.06}, {"oak", 0.12}},
    birch = {0.5, {birch, 0.75}, {"oak", 0.15}, {spruce, 0.1}},
    meadow = {0.05, {"oak", 0.7}, {birch, 0.3}},
    swamp = {0.22, {dead_tree, 0.45}, {birch, 0.35}, {spruce, 0.2}},
    hills = {0.2, {spruce, 0.8}, {"oak", 0.2}},
    river = {0.06, {birch, 0.6}, {"oak", 0.4}},
    town = {0.05, {"oak", 1}},
}

local SMALL = {
    forest = {bush = 0.008, log = 0.004, rock = 0.002},
    birch = {bush = 0.014, log = 0.002, rock = 0.001},
    meadow = {bush = 0.006, rock = 0.0004},
    swamp = {bush = 0.01, log = 0.006},
    hills = {bush = 0.004, rock = 0.03, outcrop = 0.008},
    river = {bush = 0.01},
    town = {bush = 0.002},
}

local function pick(mix, r)
    local total = 0
    for i = 2, #mix do total = total + mix[i][2] end
    r = r * total
    for i = 2, #mix do
        r = r - mix[i][2]
        if r <= 0 then
            return mix[i][1]
        end
    end
    return mix[#mix][1]
end

local function clear(wx, wz, radius)
    local k = radius - 1
    for _, o in ipairs({{0, 0}, {radius, 0}, {-radius, 0}, {0, radius}, {0, -radius}, {k, k}, {-k, k}, {k, -k}, {-k, -k}}) do
        if town.column(wx + o[1], wz + o[2]) ~= nil or countryside.occupied(wx + o[1], wz + o[2]) then
            return false
        end
    end
    return true
end

local function flat_line(hmap, lx, lz, dx, dz, n, h)
    for i = 1, n - 1 do
        local x, z = lx + dx * i, lz + dz * i
        if x > 15 or z > 15 or math.floor(hmap:at(x, z) * 256) ~= h then
            return false
        end
    end
    return true
end

-- vegetation and rocks for one wild column; h is the surface height
function flora.column(out, wx, wz, lx, lz, h, biome, hmap, seed)
    if h < SEA then
        return
    end
    local y = h + 1
    local cx, cz = math.floor(wx / CELL), math.floor(wz / CELL)
    local spot = math.floor(hash(cx, cz, seed + 41) * CELL * CELL)
    local mix = MIX[biome]
    if wx - cx * CELL == spot % CELL and wz - cz * CELL == math.floor(spot / CELL) then
        if hash(cx, cz, seed + 42) < mix[1] then
            local kind = pick(mix, hash(cx, cz, seed + 43))
            if clear(wx, wz, kind == "oak" and 6 or 3) then
                local r = hash(wx, wz, seed + 44)
                if kind == "oak" then
                    out[#out + 1] = {"tree" .. math.floor(r * 3), {lx - 3, h, lz - 3}, math.floor(r * 40) % 4, 1}
                else
                    kind(out, wx, y, wz, r)
                end
            end
            return
        end
    end
    local small = SMALL[biome]
    local r = hash(wx, wz, seed + 45)
    local acc = 0
    for _, name in ipairs({"bush", "log", "rock", "outcrop"}) do
        local p = small[name]
        if p then
            acc = acc + p
            if r < acc then
                local r2 = hash(wz, wx, seed + 46)
                if not clear(wx, wz, 1) then
                    return
                end
                if name == "bush" then
                    bush(out, wx, y, wz, r2)
                elseif name == "log" then
                    local along_x = r2 < 0.5
                    local n = 3 + math.floor(r2 * 6) % 3
                    if flat_line(hmap, lx, lz, along_x and 1 or 0, along_x and 0 or 1, n, h) then
                        for i = 0, n - 1 do
                            put(out, "zomboid:nature_log", wx + (along_x and i or 0), y, wz + (along_x and 0 or i),
                                along_x and 0 or 1)
                        end
                    end
                elseif name == "rock" then
                    boulder(out, wx, h, wz, r2, biome == "hills" and r2 > 0.6)
                else
                    outcrop(out, wx, h, wz, r2)
                end
                return
            end
        end
    end
end

return flora
