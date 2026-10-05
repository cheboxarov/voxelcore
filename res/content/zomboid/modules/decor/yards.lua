local town = require "zomboid:town"
local util = require "zomboid:decor/_util"

local hash = town.hash

local yards = {zones = util.ZONES}

local lots = {}

local function front_dir(p)
    local x0, z0 = town.to_world(p, 0, 0)
    local x1, z1 = town.to_world(p, 0, -1)
    return x1 - x0, z1 - z0
end

local function builder(p)
    local b = {blocks = {}, clear = {}}
    function b.lawn(hx, hz)
        local x, z = town.to_world(p, hx, hz)
        if town.column(x, z) ~= "lawn" or b.blocks[util.key(x, z)] then
            return nil
        end
        if p.car and math.abs(hx - p.car[1]) <= 2 and math.abs(hz - p.car[2]) <= 2 then
            return nil
        end
        for _, d in ipairs(util.DIRS) do
            local nx, nz = hx + d[1], hz + d[2]
            if nx >= 0 and nx < p.w and nz >= 0 and nz < p.d then
                local out = {}
                p.def.column(p, nx, nz, out)
                for _, e in ipairs(out) do
                    if e[2] == "base:wooden_door" or e[2] == "zomboid:door_barricade" then
                        return nil
                    end
                end
            end
        end
        return x, z
    end
    function b.put(hx, hz, entries)
        local x, z = b.lawn(hx, hz)
        if x then
            util.put(b.blocks, x, z, entries)
            b.clear[util.key(x, z)] = true
        end
        return x ~= nil
    end
    function b.wide(name, cells, rot, sx, sz)
        local minx, minz
        for _, h in ipairs(cells) do
            local x, z = b.lawn(h[1], h[2])
            if x == nil then
                return false
            end
            minx, minz = math.min(minx or x, x), math.min(minz or z, z)
        end
        local ox, oz = util.origin(minx, minz, rot, sx, sz)
        for _, f in ipairs(util.wide(b.blocks, name, ox, oz, rot, sx, sz)) do
            b.clear[util.key(f[1], f[2])] = true
        end
        return true
    end
    return b
end

local function front_fence(b, p, hedge)
    local fx, fz = front_dir(p)
    local front = -p.oz
    for hx = -p.ox, p.lot_w - p.ox - 1 do
        local gap = math.abs(hx - p.door) <= (hedge and 2 or 0)
        if not gap then
            b.put(hx, front, {{1, hedge and "zomboid:decor_hedge" or "zomboid:decor_fence", fx ~= 0 and 1 or 0}})
        end
    end
end

local function house(b, p)
    local seed = p.cx * 131 + p.cz
    local fx, fz = front_dir(p)
    if hash(seed, 1, 92) < 0.8 then
        b.put(p.door + 1, -p.oz, {{1, "zomboid:decor_mailbox", util.face(fx, fz)}})
    end
    b.put(p.w, p.d - 2, {{1, "zomboid:decor_trash_can", 0}})
    if hash(seed, 2, 91) < 0.6 then
        for hx = 1, p.w - 2 do
            if math.abs(hx - p.door) >= 2 then
                b.put(hx, -1, {{0, "zomboid:decor_soil", 0}, {1, "base:flower", 0}})
            end
        end
    end
    if hash(seed, 3, 93) < 0.35 and not p.classic then
        for hx = 2, 5 do
            for hz = p.d + 2, p.d + 3 do
                b.put(hx, hz, {{0, "zomboid:garden_bed", 0}})
            end
        end
    end
    if p.looted or p.boarded then
        for i = 1, 4 do
            local hx = p.door + math.floor(hash(seed, i, 94) * 5) - 2
            b.put(hx, -1 - math.floor(hash(seed, i, 95) * 2), util.decal(i % 2 == 0 and "blood" or "litter", hash(seed, i, 96)))
        end
    end
    local r = p.classic and 1 or hash(seed, 4, 90)
    if r < 0.35 then
        front_fence(b, p, false)
    elseif r < 0.55 then
        front_fence(b, p, true)
    end
end

local function store(b, p)
    local fx, fz = front_dir(p)
    local face = util.face(fx, fz)
    b.wide("zomboid:decor_dumpster", {{p.w - 4, p.d + 1}, {p.w - 3, p.d + 1}}, util.face(-fx, -fz), 2, 1)
    b.put(p.door - 2, -1, {{1, "zomboid:decor_trash_can", 0}})
    b.put(p.door + 2, -1, {{1, "zomboid:decor_trash_can", 0}})
    if p.kind == "police" then
        b.wide("zomboid:decor_wreck_police", {{-3, -3}, {-2, -3}, {-3, -2}, {-2, -2}, {-3, -1}, {-2, -1}}, face, 2, 3)
        b.put(p.door - 1, -3, {{1, "zomboid:decor_police_barrier", face % 2}})
        b.put(p.door + 1, -3, {{1, "zomboid:decor_police_barrier", face % 2}})
    end
end

local function lot(p)
    local k = util.key(p.cx, p.cz)
    local b = lots[k]
    if b == nil then
        b = builder(p)
        if p.kind == "house" then house(b, p) else store(b, p) end
        lots[k] = b
    end
    return b
end

function yards.keep_clear(wx, wz)
    local cx, cz = town.cell_at(wx, wz)
    local p = cx and town.plan(cx, cz)
    return p ~= nil and lot(p).clear[util.key(wx, wz)] == true
end

function yards.column(ctx, wx, wz, out)
    if ctx.kind ~= "lawn" or ctx.plan == nil then
        return false
    end
    if util.emit(lot(ctx.plan).blocks, wx, wz, out) then
        return true
    end
    local hx, hz = town.to_local(ctx.plan, wx, wz)
    local near = hx >= -1 and hx <= ctx.plan.w and hz >= -1 and hz <= ctx.plan.d
    if not near and not ctx.plan.classic and hash(wx, wz, 99) < 0.006 then
        table.insert(out, util.decal("litter", hash(wz, wx, 100))[1])
        return true
    end
    return false
end

return yards
