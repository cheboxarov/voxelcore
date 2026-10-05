local town = require "zomboid:town"
local util = require "zomboid:decor/_util"

local hash = town.hash

local parks = {zones = util.ZONES}

local GREEN = {park = true, suburb = true, downtown = true}

local built = {}
local stories
local places = {}

local function area(c)
    local mx, mz = math.floor((c.x0 + c.x1) / 2), math.floor((c.z0 + c.z1) / 2)
    local x0, x1, z0, z1 = c.x0, c.x1, c.z0, c.z1
    while x0 < mx and town.column(x0, mz) ~= "park" do x0 = x0 + 1 end
    while x1 > mx and town.column(x1, mz) ~= "park" do x1 = x1 - 1 end
    while z0 < mz and town.column(mx, z0) ~= "park" do z0 = z0 + 1 end
    while z1 > mz and town.column(mx, z1) ~= "park" do z1 = z1 - 1 end
    return x0, z0, x1, z1
end

local function story_cells()
    if stories then
        return stories
    end
    stories = {}
    local heli, camp
    for _, c in ipairs(town.cells()) do
        if town.plan(c.cx, c.cz) == nil then
            local r = hash(c.cx, c.cz, 70)
            if c.zone == "park" and (heli == nil or r < heli[2]) then heli = {c, r} end
            if c.zone == "outskirts" and (camp == nil or r < camp[2]) then camp = {c, r} end
        end
    end
    if heli then stories[util.key(heli[1].cx, heli[1].cz)] = "heli" end
    if camp then stories[util.key(camp[1].cx, camp[1].cz)] = "tent" end
    return stories
end

local function builder(c)
    local b = {blocks = {}, clear = {}}
    b.x0, b.z0, b.x1, b.z1 = area(c)
    b.mx, b.mz = math.floor((b.x0 + b.x1) / 2), math.floor((b.z0 + b.z1) / 2)
    function b.put(x, z, entries)
        util.put(b.blocks, x, z, entries)
        b.clear[util.key(x, z)] = true
    end
    function b.wide(name, minx, minz, rot, sx, sz)
        local ox, oz = util.origin(minx, minz, rot, sx, sz)
        for _, f in ipairs(util.wide(b.blocks, name, ox, oz, rot, sx, sz)) do
            b.clear[util.key(f[1], f[2])] = true
        end
    end
    function b.reserve(x0, z0, x1, z1)
        for x = x0, x1 do
            for z = z0, z1 do b.clear[util.key(x, z)] = true end
        end
    end
    function b.decal(name, x, z)
        b.put(x, z, util.decal(name, hash(x, z, 72)))
    end
    function b.note(place, x, z)
        b.put(x, z, {{1, "zomboid:decor_note", 0}})
        places[util.key(x, z)] = place
    end
    return b
end

local function heli(b)
    local x, z = b.mx - 2, b.mz - 3
    b.wide("zomboid:decor_heli_wreck", x, z, 0, 5, 7)
    b.reserve(x - 3, z - 3, x + 7, z + 9)
    for dx = -2, 6 do
        if dx ~= 2 then
            b.put(x + dx, z - 2, {{1, "zomboid:decor_tape", 0}})
            b.put(x + dx, z + 8, {{1, "zomboid:decor_tape", 0}})
        end
    end
    for dz = -1, 7 do
        b.put(x - 2, z + dz, {{1, "zomboid:decor_tape", 1}})
        b.put(x + 6, z + dz, {{1, "zomboid:decor_tape", 1}})
    end
    b.put(x - 1, z + 1, {{1, "zomboid:decor_army_crate", 3}})
    b.put(x + 5, z + 6, {{1, "zomboid:decor_army_crate", 1}})
    b.note("heli", x + 5, z + 1)
    for _, d in ipairs({{-1, 4, "blood"}, {1, -1, "litter"}, {5, 3, "litter"}, {3, 7, "blood"}, {-1, 6, "litter"}}) do
        b.decal(d[3], x + d[1], z + d[2])
    end
end

local function camp(b)
    local x, z = b.mx - 6, b.mz - 6
    b.reserve(x - 1, z - 1, x + 14, z + 14)
    b.wide("zomboid:decor_tent", x + 1, z + 1, 3, 3, 3)
    b.wide("zomboid:decor_tent", x + 1, z + 6, 3, 3, 3)
    b.wide("zomboid:decor_tent", x + 7, z + 1, 2, 3, 3)
    b.put(x + 6, z + 6, {{1, "zomboid:decor_firepit", 0}})
    b.put(x + 7, z + 7, {{1, "zomboid:decor_bench", 1}})
    b.put(x + 4, z + 11, {{1, "zomboid:crate", 0}})
    b.put(x + 5, z + 11, {{1, "zomboid:crate", 0}})
    b.put(x + 9, z + 9, {{1, "zomboid:decor_trash_can", 0}})
    b.note("tent", x + 5, z + 5)
    for d = 0, 13 do
        if d % 5 ~= 2 then
            b.put(x + d, z, {{1, "zomboid:palisade", 0}})
            b.put(x + d, z + 13, {{1, "zomboid:palisade", 0}})
        end
        if d > 0 and d < 13 and d % 4 ~= 1 and (d < 5 or d > 8) then
            b.put(x + 13, z + d, {{1, "zomboid:palisade", 0}})
        end
    end
    for _, d in ipairs({{5, 8, "blood"}, {8, 5, "litter"}, {10, 7, "blood"}, {3, 10, "litter"}, {11, 11, "litter"}}) do
        b.decal(d[3], x + d[1], z + d[2])
    end
end

local function park(b, c)
    local mx, mz = b.mx, b.mz
    for x = b.x0, b.x1 do b.put(x, mz, {{0, "zomboid:decor_gravel", 0}}) end
    for z = b.z0, b.z1 do b.put(mx, z, {{0, "zomboid:decor_gravel", 0}}) end
    for _, d in ipairs({{-2, -2}, {2, -2}, {-2, 2}, {2, 2}}) do
        b.put(mx + d[1], mz + d[2], {{0, "zomboid:decor_soil", 0}, {1, "base:flower", 0}})
    end
    for _, s in ipairs({{-7, -1, 2}, {7, 1, 0}, {-1, 7, 3}, {1, -7, 1}}) do
        b.put(mx + s[1], mz + s[2], {{1, "zomboid:decor_bench", s[3]}})
    end
    b.put(mx - 6, mz - 1, {{1, "zomboid:decor_trash_can", 0}})
    b.put(mx + 1, mz - 6, {{1, "zomboid:decor_trash_can", 0}})
    for _, l in ipairs({{-1, -4, 3}, {1, 5, 1}, {-4, 1, 0}, {5, -1, 2}}) do
        b.put(mx + l[1], mz + l[2], util.lamp(l[3]))
    end
    if mx - b.x0 >= 10 and mz - b.z0 >= 10 and hash(c.cx, c.cz, 73) < 0.8 then
        local x, z = b.x0 + 1, b.z0 + 1
        b.reserve(b.x0, b.z0, mx - 2, mz - 2)
        for dx = 1, 4 do
            for dz = 1, 4 do
                local edge = dx == 1 or dx == 4 or dz == 1 or dz == 4
                b.put(x + dx, z + dz, edge and {{1, "zomboid:wood_floor", 0}} or {{0, "base:sand", 0}})
            end
        end
        b.wide("zomboid:decor_swing", x, z + 7, 2, 3, 1)
        b.wide("zomboid:decor_slide", x + 6, z + 1, 0, 1, 3)
        b.put(x + 4, z + 7, {{1, "zomboid:decor_bench", 2}})
    end
end

local function get(c)
    local k = util.key(c.cx, c.cz)
    local b = built[k]
    if b == nil then
        b = builder(c)
        local story = story_cells()[k]
        if story == "heli" then
            heli(b)
        elseif story == "tent" then
            camp(b)
        elseif GREEN[c.zone] and b.x1 - b.x0 >= 14 and b.z1 - b.z0 >= 14 then
            park(b, c)
        end
        built[k] = b
    end
    return b
end

function parks.place_at(wx, wz)
    local cx, cz = town.cell_at(wx, wz)
    local c = cx and util.cell(cx, cz)
    if c == nil or story_cells()[util.key(cx, cz)] == nil then
        return nil
    end
    get(c)
    return places[util.key(wx, wz)]
end

function parks.keep_clear(wx, wz)
    local cx, cz = town.cell_at(wx, wz)
    local c = cx and util.cell(cx, cz)
    return c ~= nil and town.plan(cx, cz) == nil and get(c).clear[util.key(wx, wz)] == true
end

function parks.column(ctx, wx, wz, out)
    if ctx.kind ~= "park" or ctx.cx == nil or ctx.zone == "plaza" then
        return false
    end
    local b = get(util.cell(ctx.cx, ctx.cz))
    if util.emit(b.blocks, wx, wz, out) then
        return true
    end
    if hash(wx, wz, 74) < 0.004 then
        table.insert(out, util.decal("litter", hash(wz, wx, 75))[1])
        return true
    end
    return false
end

return parks
