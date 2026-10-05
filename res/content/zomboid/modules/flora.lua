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

-- baked fragments per kind (dev/zomboid/tree_fragments.lua), 7×7 around the trunk; "tree" are the old oaks
local VARIANTS = {spruce = 6, birch = 4, dead = 3, tree = 3}

-- {density per 4x4 cell, {fragment kind, weight}...}
local MIX = {
    forest = {0.62, {"spruce", 0.82}, {"birch", 0.06}, {"tree", 0.12}},
    birch = {0.5, {"birch", 0.75}, {"tree", 0.15}, {"spruce", 0.1}},
    meadow = {0.05, {"tree", 0.7}, {"birch", 0.3}},
    swamp = {0.22, {"dead", 0.45}, {"birch", 0.35}, {"spruce", 0.2}},
    hills = {0.2, {"spruce", 0.8}, {"tree", 0.2}},
    river = {0.06, {"birch", 0.6}, {"tree", 0.4}},
    town = {0.05, {"tree", 1}},
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

local SMALL_KINDS = {"bush", "log", "rock", "outcrop"}
local SMALL_MAX = 0
for _, small in pairs(SMALL) do
    local sum = 0
    for _, p in pairs(small) do sum = sum + p end
    SMALL_MAX = math.max(SMALL_MAX, sum)
end

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

local AROUND = {{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}}
local DIAGONAL = {{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}

local function free(x, z)
    return town.column(x, z) == nil and not countryside.near_road(x, z)
end

local function clear(wx, wz, radius)
    for _, o in ipairs(AROUND) do
        if not free(wx + o[1] * radius, wz + o[2] * radius) then
            return false
        end
    end
    local k = radius - 1
    for _, o in ipairs(DIAGONAL) do
        if k > 0 and not free(wx + o[1] * k, wz + o[2] * k) then
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

-- dry land under a 3×3 footprint inside the chunk
local function dry(hmap, lx, lz)
    if lx > 13 or lz > 13 then
        return false
    end
    for i = 0, 2 do
        for j = 0, 2 do
            if hmap:at(lx + i, lz + j) * 256 < SEA then
                return false
            end
        end
    end
    return true
end

-- vegetation and rocks for one wild column; h is the surface height, biome_at(lx, lz) is asked only when needed
function flora.column(out, wx, wz, lx, lz, h, biome_at, hmap, seed)
    if h < SEA then
        return
    end
    local y = h + 1
    local cx, cz = math.floor(wx / CELL), math.floor(wz / CELL)
    local spot = math.floor(hash(cx, cz, seed + 41) * CELL * CELL)
    local biome
    if wx - cx * CELL == spot % CELL and wz - cz * CELL == math.floor(spot / CELL) then
        biome = biome_at(lx, lz)
        local mix = MIX[biome]
        if hash(cx, cz, seed + 42) < mix[1] then
            local kind = pick(mix, hash(cx, cz, seed + 43))
            if clear(wx, wz, kind == "tree" and 6 or 3) then
                local r = hash(wx, wz, seed + 44)
                local name = kind .. math.floor(r * VARIANTS[kind])
                out[#out + 1] = {name, {lx - 3, kind == "tree" and h or y, lz - 3}, math.floor(r * 40) % 4, 1}
            end
            return
        end
    end
    local r = hash(wx, wz, seed + 45)
    if r >= SMALL_MAX then
        return
    end
    local small = SMALL[biome or biome_at(lx, lz)]
    local acc = 0
    for _, name in ipairs(SMALL_KINDS) do
        local p = small[name]
        if p then
            acc = acc + p
            if r < acc then
                local r2 = hash(wz, wx, seed + 46)
                if not clear(wx, wz, 1) or name ~= "log" and not dry(hmap, lx, lz) then
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
