local kit = {}

local H = 4
local AIR = "core:struct_air"

local KEYS = {"wall", "inner", "floor", "floor2", "roof", "window", "stair", "slab"}
local DEFAULTS = {
    wall = "base:brick",
    inner = "zomboid:siding_white",
    floor = "base:planks",
    floor2 = "zomboid:tiles",
    roof = "zomboid:roof",
    window = "zomboid:window",
    stair = "base:planks",
    slab = "zomboid:wood_floor",
}

local SANDBAG = "zomboid:bld_sandbag"
local LADDER = "zomboid:ladder"

local LEGEND = {
    ["."] = {},
    Q = {lamp = true, void = true},
    [":"] = {g = "$floor2"},
    L = {lamp = true},
    [";"] = {g = "$floor2", lamp = true},
    f = {"zomboid:fridge", h = 2, face = true},
    s = {"zomboid:shelf", h = 2, face = true},
    c = {"zomboid:crate"},
    k = {"zomboid:kitchen_cabinet", face = true},
    o = {"zomboid:stove", face = true},
    n = {"zomboid:sink", face = true},
    b = {"zomboid:bed", face = true},
    w = {"zomboid:wardrobe", h = 2, face = true},
    m = {"zomboid:medicine_cabinet", face = true},
    u = {"zomboid:couch", face = true},
    t = {"zomboid:tv", face = true},
    l = {"zomboid:bld_locker", h = 2, face = true},
    d = {"zomboid:bld_table"},
    B = {false, "zomboid:bld_chalkboard", face = true},
    p = {"zomboid:bld_pew", face = true},
    a = {"zomboid:bld_ammo_crate", face = true},
    v = {"zomboid:car_spawner", g = "zomboid:asphalt"},
    G = {g = "zomboid:asphalt", gap = true},
    ["_"] = {g = "zomboid:sidewalk", out = true},
    ['"'] = {g = "base:grass_block", out = true},
    ["="] = {g = "zomboid:asphalt", out = true},
    [","] = {g = "base:dirt", out = true},
    V = {"zomboid:car_spawner", g = "zomboid:asphalt", out = true},
    g = {"zomboid:bld_gravestone", g = "base:grass_block", out = true, face = true},
    x = {SANDBAG, SANDBAG, g = "base:dirt", out = true},
    y = {SANDBAG, g = "base:dirt", out = true},
    ["|"] = {"zomboid:bld_fence", "zomboid:bld_fence", g = "base:grass_block", out = true},
    P = {"base:wood", "base:wood", "base:wood", "base:wood", "base:wood", SANDBAG, g = "base:dirt", out = true},
    R = {false, false, false, false, "base:planks", SANDBAG, g = "base:dirt", out = true},
    O = {false, false, false, false, "base:planks", g = "base:dirt", out = true},
    H = {LADDER, LADDER, LADDER, LADDER, LADDER, LADDER, g = "base:dirt", out = true, rot = 0},
}

local WALLS = {["#"] = "$wall", W = "$wall", ["%"] = "$inner"}
local WALKABLE = {["."] = true, [":"] = true, L = true, [";"] = true, D = true, G = true, v = true,
    ["_"] = true, ['"'] = true, ["="] = true, [","] = true}
local ROOMS = {["."] = true, [":"] = true, L = true, [";"] = true}
local FACING = {{0, -1, 2}, {1, 0, 1}, {0, 1, 0}, {-1, 0, 3}}
local MIRROR = {[0] = 0, 3, 2, 1}

local function compile(def)
    local floors = def.floors
    local w, d = #floors[1][1], #floors[1]
    for i, rows in ipairs(floors) do
        assert(#rows == d, def.kind .. " floor " .. i .. " depth")
        for z, row in ipairs(rows) do
            assert(#row == w, def.kind .. " floor " .. i .. " row " .. z .. " width " .. #row)
        end
    end
    local legend = setmetatable(def.legend or {}, {__index = LEGEND})
    local function at(f, x, z)
        local rows = floors[f + 1]
        if rows == nil or x < 0 or z < 0 or x >= w or z >= d then
            return " "
        end
        return rows[z + 1]:sub(x + 1, x + 1)
    end
    local function outside(f, x, z)
        local c = at(f, x, z)
        return c == " " or (legend[c] and legend[c].out) or false
    end
    local function edge(f, x, z)
        return outside(f, x - 1, z) or outside(f, x + 1, z) or outside(f, x, z - 1) or outside(f, x, z + 1)
    end

    local cells, spots, yard, door, car = {}, {}, {}, nil, nil
    for z = 0, d - 1 do
        for x = 0, w - 1 do
            local list, n, top = {}, 0, nil
            local function add(dy, name, rot, faced)
                table.insert(list, {dy, name, rot or 0, faced})
            end
            for f = 0, #floors - 1 do
                local c = at(f, x, z)
                if c == " " then
                    break
                end
                local e = legend[c]
                local base = f * H
                local occ = {}
                local rot, faced = 0, false
                if e and e.face then
                    faced = true
                    rot = nil
                    for _, dir in ipairs(FACING) do
                        if rot == nil and WALLS[at(f, x + dir[1], z + dir[2])] then
                            rot = (dir[3] + 2) % 4
                        end
                    end
                    for _, dir in ipairs(FACING) do
                        if rot == nil and WALKABLE[at(f, x + dir[1], z + dir[2])] then
                            rot = dir[3]
                        end
                    end
                    rot = rot or 0
                elseif e and e.rot then
                    rot = e.rot
                end
                if e and e.out then
                    add(0, e.g)
                    for i = 1, 8 do
                        if e[i] then add(i, e[i], rot, faced) end
                    end
                    for i = 1, 3 do
                        if not e[i] then add(i, AIR) end
                    end
                    if WALKABLE[c] then
                        table.insert(yard, {x, z})
                    end
                    if c == "V" then car = car or {x, z} end
                    break
                end
                n, top = f + 1, c
                local below = f > 0 and at(f - 1, x, z) or nil
                local open = c == "0" or (e and e.void) or (below and below:match("%d") ~= nil)
                local digit = tonumber(c)
                if not open then
                    add(base, WALLS[c] or (e and e.g) or "$floor")
                end
                if digit and digit > 0 then
                    local dy = base + math.ceil(digit / 2)
                    add(dy, digit % 2 == 0 and "$stair" or "$slab")
                    occ[dy - base] = true
                elseif WALLS[c] then
                    local mat = WALLS[c]
                    add(base + 1, c == "W" and "$window" or mat)
                    add(base + 2, c == "W" and "$window" or mat)
                    add(base + 3, mat)
                    occ = {true, true, true}
                elseif c == "D" then
                    local horizontal = WALLS[at(f, x - 1, z)] or WALLS[at(f, x + 1, z)] or at(f, x - 1, z) == "D"
                        or at(f, x + 1, z) == "D"
                    add(base + 1, "base:wooden_door", horizontal and 0 or 1)
                    add(base + 3, edge(f, x, z) and "$wall" or "$inner")
                    occ = {true, true, true}
                    if f == 0 and door == nil then door = x end
                elseif e then
                    for i = 1, 3 do
                        if e[i] then
                            add(base + i, e[i], rot, faced)
                            for k = i, i + (e.h or 1) - 1 do occ[k] = true end
                        end
                    end
                    if e.lamp then
                        add(base + 3, "zomboid:lamp")
                        occ[3] = true
                    elseif e.gap then
                        add(base + 3, "$wall")
                        occ[3] = true
                    end
                    if c == "v" then car = car or {x, z} end
                    if ROOMS[c] then
                        table.insert(spots, {x, f, z})
                    end
                end
                if f == 0 then
                    for i = 1, 3 do
                        if not occ[i] then add(i, AIR) end
                    end
                end
            end
            if n > 0 then
                add(H * n, "$roof")
                if WALLS[top] and edge(n - 1, x, z) then
                    add(H * n + 1, WALLS[top])
                end
                local e = legend[top]
                if e and e.top then
                    for i, name in ipairs(e.top) do
                        if name then add(H * n + i, name) end
                    end
                end
            end
            cells[z * w + x] = list
        end
    end
    def.w, def.d, def.grid, def.spots, def.yard, def.car = w, d, cells, spots, yard, car
    def.door = def.door or door
    def.ground = {}
    for z = 0, d - 1 do
        for x = 0, w - 1 do
            local e = outside(0, x, z) and legend[at(0, x, z)]
            def.ground[z * w + x] = e and (e.g == "base:grass_block" and "lawn" or "path") or nil
        end
    end
end

function kit.building(def)
    compile(def)
    local w = def.w
    local materials = setmetatable(def.materials or {}, {__index = DEFAULTS})

    function def.plan(p, hash)
        p.w, p.d = def.w, def.d
        p.oz = math.min(3, math.max(0, p.lot_d - p.d))
        p.flip = def.mirror ~= false and hash(1) < 0.5
        for i, key in ipairs(KEYS) do
            local m = materials[key]
            if type(m) == "table" then
                m = m[1 + math.floor(hash(i + 1) * #m)]
            end
            p[key] = m
        end
        local function mx(x) return p.flip and w - 1 - x or x end
        p.door = mx(def.door or math.floor(w / 2))
        if def.car then
            p.car = {mx(def.car[1]), def.car[2]}
        end
    end

    function def.column(p, hx, hz, out)
        local list = def.grid[hz * w + (p.flip and w - 1 - hx or hx)]
        for _, e in ipairs(list) do
            local name = e[2]
            if name:byte(1) == 36 then
                name = p[name:sub(2)]
            end
            table.insert(out, {e[1], name, (p.flip and e[4]) and MIRROR[e[3]] or e[3]})
        end
    end

    function def.kind_at(p, hx, hz)
        return def.ground[hz * w + (p.flip and w - 1 - hx or hx)]
    end

    function def.spot(p, rand, outdoor)
        local list = outdoor and def.yard or def.spots
        if #list == 0 then
            return nil
        end
        local s = list[rand(1, #list)]
        local x = p.flip and w - 1 - s[1] or s[1]
        if outdoor then
            return x, 0, s[2]
        end
        return x, s[2], s[3]
    end

    return def
end

kit.FLOOR_HEIGHT = H

return kit
