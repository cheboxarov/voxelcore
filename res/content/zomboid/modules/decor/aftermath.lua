local town = require "zomboid:town"
local util = require "zomboid:decor/_util"

local hash = town.hash

local aftermath = {zones = {"wild"}}
for _, z in ipairs(util.ZONES) do table.insert(aftermath.zones, z) end

local PAINTS = {"red", "blue", "white", "burnt"}
local STREET = {road = true, sidewalk = true}
local CORDON_X = -252

local blocks, occupied, places, clear

local function free(cells, kinds)
    for _, c in ipairs(cells) do
        if occupied[util.key(c[1], c[2])] or not kinds[town.column(c[1], c[2]) or "wild"] then
            return false
        end
    end
    return true
end

local function extended(name, minx, minz, rot, sx, sz, kinds)
    local ox, oz = util.origin(minx, minz, rot, sx, sz)
    if kinds and not free(util.footprint(ox, oz, rot, sx, sz), kinds) then
        return false
    end
    for _, c in ipairs(util.wide(blocks, name, ox, oz, rot, sx, sz)) do
        occupied[util.key(c[1], c[2])] = true
    end
    return true
end

local function single(x, z, entries)
    occupied[util.key(x, z)] = true
    util.put(blocks, x, z, entries)
end

local function decal(name, x, z)
    single(x, z, util.decal(name, hash(x, z, 3)))
end

local function note(place, x, z)
    single(x, z, {{1, "zomboid:decor_note", 0}})
    places[util.key(x, z)] = place
end

-- A street side of a cell: point(t, k) is t along the cell edge and k steps outward from it (k = 0 is the edge column).
local function side(c, i)
    local d = util.DIRS[i]
    local s = {c = c, dx = d[1], dz = d[2], along_x = d[1] == 0}
    s.a, s.b = (s.along_x and c.x0 or c.z0), (s.along_x and c.x1 or c.z1)
    local edge = (d[1] < 0 and c.x0) or (d[1] > 0 and c.x1) or (d[2] < 0 and c.z0) or c.z1
    function s.point(t, k)
        if s.along_x then return t, edge + d[2] * k end
        return edge + d[1] * k, t
    end
    local mx, mz = s.point(math.floor((s.a + s.b) / 2), 1)
    s.width = util.run(mx, mz, d[1], d[2], "road", 12)
    s.walk = town.column(s.point(math.floor((s.a + s.b) / 2), 0)) == "sidewalk"
    s.far_walk = town.column(s.point(math.floor((s.a + s.b) / 2), s.width + 1)) == "sidewalk"
    return s
end

local function rect(s, t0, t1, k0, k1)
    local x0, z0 = s.point(t0, k0)
    local x1, z1 = s.point(t1, k1)
    return math.min(x0, x1), math.min(z0, z1)
end

local function car(s, t0, paint, flip)
    local k0, k1 = 0, 1
    if not s.walk then k0, k1 = 1, 2 end
    local minx, minz = rect(s, t0, t0 + 2, k0, k1)
    local rot = (s.along_x and 1 or 0) + (flip and 2 or 0)
    return extended("zomboid:decor_wreck_" .. paint, minx, minz, rot, 2, 3, STREET)
end

local function bus(s)
    local t = math.floor((s.a + s.b) / 2) - 1
    local minx, minz = rect(s, t, t + 2, -1, 7)
    if not extended("zomboid:decor_bus_wreck", minx, minz, s.along_x and 0 or 1, 3, 9, STREET) then
        return false
    end
    note("bus", s.point(t + 4, -1))
    for i, k in ipairs({1, 3, 5}) do
        decal("blood", s.point(t + 3 + i, k))
    end
    return true
end

local function police(s)
    local t = math.floor((s.a + s.b) / 2)
    local rot = s.along_x and 1 or 0
    for _, k in ipairs({1, 5}) do
        local x, z = s.point(t, k)
        single(x, z, {{1, "zomboid:decor_police_barrier", rot}})
    end
    for _, k in ipairs({-1, 0, 6, 7}) do
        local x, z = s.point(t, k)
        if town.column(x, z) == "sidewalk" and not occupied[util.key(x, z)] then
            single(x, z, {{1, "zomboid:decor_tape", rot}})
        end
    end
    car(s, t + 3, "police")
    note("police", s.point(t - 2, -1))
    for _, d in ipairs({{-1, 2}, {1, 3}, {4, 2}}) do
        decal("blood", s.point(t + d[1], d[2]))
    end
end

local function camp_spot()
    for x = CORDON_X, CORDON_X - 120, -6 do
        local z0, z1
        for z = -45, 45 do
            if town.column(x, z) == "road" then
                z0, z1 = z0 or z, z
            end
        end
        local wild = z0 ~= nil
        for dx = -13, 3 do
            for dz = -16, -1 do
                wild = wild and town.column(x + dx, z0 + dz) == nil
            end
        end
        if wild then
            return x, z0, z1
        end
    end
end

local function cordon()
    local x, z0, z1 = camp_spot()
    if x == nil then
        return
    end
    for _, z in ipairs({z0, z0 + 1, z1 - 1, z1}) do
        single(x, z, {{1, "zomboid:decor_sandbags", 1}, {2, "zomboid:decor_sandbags", 1}})
    end
    local wall = z0 - 2
    for dx = -12, 3 do
        for dz = -15, -2 do clear[util.key(x + dx, z0 + dz)] = true end
        if dx < -6 or dx > -4 then
            single(x + dx, wall, {{1, "zomboid:decor_sandbags", 0}, {2, "zomboid:decor_sandbags", 0}})
        end
    end
    extended("zomboid:decor_wreck_army", x - 2, wall - 4, 1, 2, 3)
    extended("zomboid:decor_tent", x - 12, wall - 11, 2, 3, 3)
    extended("zomboid:decor_tent", x - 7, wall - 11, 2, 3, 3)
    for _, c in ipairs({{-11, -6}, {-10, -6}, {-1, -9}}) do
        single(x + c[1], wall + c[2], {{1, "zomboid:decor_army_crate", 2}})
    end
    single(x - 6, wall - 5, {{1, "zomboid:decor_firepit", 0}})
    note("cordon", x - 4, wall - 3)
    single(x - 13, wall - 1, util.lamp(2))
    single(x + 2, wall - 1, util.lamp(2))
    for _, c in ipairs({{-8, -3, "litter"}, {-3, -7, "litter"}, {0, -2, "blood"}, {-9, -9, "litter"}}) do
        decal(c[3], x + c[1], wall + c[2])
    end
end

local function highway()
    for x = 190, 540, 23 do
        if hash(x, 0, 52) < 0.6 then
            local hz = math.floor(town.highway_z(x) + 0.5)
            local up = hash(x, 1, 53) < 0.5
            local z = up and hz - town.HIGHWAY_HALF or hz + town.HIGHWAY_HALF - 1
            extended("zomboid:decor_wreck_" .. PAINTS[1 + math.floor(hash(x, 2, 54) * #PAINTS)], x, z,
                hash(x, 3, 55) < 0.5 and 1 or 3, 2, 3, {road = true})
        end
    end
end

local function init()
    if blocks then
        return
    end
    blocks, occupied, places, clear = {}, {}, {}, {}
    local streets, best_bus = {}, nil
    for _, c in ipairs(town.cells()) do
        for i = 1, 4 do
            local s = side(c, i)
            if s.width == 5 and c.zone ~= "plaza" and (s.walk or (not s.far_walk and i <= 2)) then
                s.r = hash(c.cx * 4 + i, c.cz, 41)
                table.insert(streets, s)
            end
        end
    end
    table.sort(streets, function(p, q) return p.r < q.r end)
    for _, s in ipairs(streets) do
        if s.c.zone == "suburb" and s.walk and s.far_walk and bus(s) then
            best_bus = s
            break
        end
    end
    local cops = 0
    for _, s in ipairs(streets) do
        if cops < 2 and s ~= best_bus and s.c.zone == "downtown" and s.walk and s.far_walk then
            police(s)
            cops = cops + 1
        end
    end
    cordon()
    highway()
    for _, s in ipairs(streets) do
        local span = s.b - s.a - 12
        if s ~= best_bus and s.r < 0.45 and span > 0 then
            local c = s.c
            car(s, s.a + 5 + math.floor(hash(c.cx, c.cz, 44) * span), PAINTS[1 + math.floor(s.r * 97) % #PAINTS], s.r < 0.2)
        end
    end
end

function aftermath.occupied(wx, wz)
    init()
    return occupied[util.key(wx, wz)] == true
end

function aftermath.keep_clear(wx, wz)
    init()
    local k = util.key(wx, wz)
    return occupied[k] or clear[k] or false
end

function aftermath.place_at(wx, wz)
    init()
    return places[util.key(wx, wz)]
end

function aftermath.column(ctx, wx, wz, out)
    init()
    if util.emit(blocks, wx, wz, out) then
        return true
    end
    if ctx.kind ~= "road" then
        return false
    end
    local r = hash(wx, wz, 49)
    if r >= 0.025 then
        return false
    end
    local wide_x = util.run(wx, wz, 1, 0, "road", 6) + util.run(wx, wz, -1, 0, "road", 6)
    local wide_z = util.run(wx, wz, 0, 1, "road", 6) + util.run(wx, wz, 0, -1, "road", 6)
    if math.min(wide_x, wide_z) > 6 then
        return false
    end
    table.insert(out, util.decal(r < 0.018 and "litter" or "blood", hash(wz, wx, 50))[1])
    return true
end

return aftermath
