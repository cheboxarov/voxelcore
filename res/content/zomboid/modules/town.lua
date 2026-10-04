local town = {}

town.GROUND = 40
town.SEA_LEVEL = 38
town.CELL = 32
town.RADIUS = 3
town.ROAD = 5
town.LOT_MIN = 7
town.LOT_SIZE = 23
town.FLAT_EXTENT = town.CELL * town.RADIUS + 28

local CELL = town.CELL
local R = town.RADIUS
local GROUND = town.GROUND

local function hash(a, b, c)
    local h = bit.bxor(a * 374761393, b * 668265263)
    h = bit.bxor(h, (c or 0) * 2246822519)
    h = bit.bxor(h, bit.rshift(h, 13)) * 1274126177
    h = bit.bxor(h, bit.rshift(h, 16))
    return bit.band(h, 0x7FFFFFFF) / 0x7FFFFFFF
end
town.hash = hash

local function load_dir(dir)
    local names = {}
    local path = "zomboid:modules/" .. dir
    if file.isdir(path) then
        for _, f in ipairs(file.list(path)) do
            local name = f:match("([^/:]+)%.lua$")
            if name and name:sub(1, 1) ~= "_" then
                table.insert(names, name)
            end
        end
    end
    table.sort(names)
    local list = {}
    for _, name in ipairs(names) do
        table.insert(list, require("zomboid:" .. dir .. "/" .. name))
    end
    return list
end

local registry

local function reg()
    if registry then
        return registry
    end
    registry = {list = load_dir("buildings"), by_kind = {}, pick = {}, decor = {}}
    for _, def in ipairs(registry.list) do
        registry.by_kind[def.kind] = def
        for _, zone in ipairs(def.zones or {}) do
            local key = zone .. ":" .. (def.cells or 1)
            registry.pick[key] = registry.pick[key] or {}
            table.insert(registry.pick[key], {def.kind, def.weight or 1})
        end
    end
    for _, d in ipairs(load_dir("decor")) do
        for _, zone in ipairs(d.zones or {}) do
            registry.decor[zone] = registry.decor[zone] or {}
            table.insert(registry.decor[zone], d)
        end
    end
    return registry
end

function town.building_defs()
    return reg().list
end

function town.building_def(kind)
    return reg().by_kind[kind]
end

local PARK_WEIGHT = {downtown = 12, suburb = 12}

local function cell_of(w)
    return math.floor(w / CELL), w % CELL
end

function town.cell_at(wx, wz)
    local cx, lx = cell_of(wx)
    local cz, lz = cell_of(wz)
    return cx, cz, lx, lz
end

function town.in_town(wx, wz)
    local limit = CELL * R + town.ROAD
    return wx >= -CELL * R and wx < limit and wz >= -CELL * R and wz < limit
end

function town.zone(cx, cz)
    if cx < -R or cz < -R or cx >= R or cz >= R then
        return nil
    end
    if cx >= -1 and cx <= 0 and cz >= -1 and cz <= 0 then
        return "downtown"
    end
    return "suburb"
end

local FORCED = {["0:0"] = "house", ["-1:0"] = "grocery", ["1:2"] = "gas_station"}

function town.lot_kind(cx, cz)
    local zone = town.zone(cx, cz)
    if zone == nil then
        return nil
    end
    local forced = FORCED[cx .. ":" .. cz]
    if forced then
        return forced
    end
    local options = reg().pick[zone .. ":1"] or {}
    local total = PARK_WEIGHT[zone] or 0
    for _, o in ipairs(options) do total = total + o[2] end
    local r = hash(cx, cz, 17) * total
    for _, o in ipairs(options) do
        r = r - o[2]
        if r < 0 then
            return o[1]
        end
    end
    return "park"
end

function town.to_world(p, hx, hz)
    local rot = p.rot
    if rot == 0 then
        return p.x0 + hx, p.z0 + hz
    elseif rot == 1 then
        return p.x0 + hz, p.z1 - hx
    elseif rot == 2 then
        return p.x1 - hx, p.z1 - hz
    end
    return p.x1 - hz, p.z0 + hx
end

function town.to_local(p, wx, wz)
    local rot = p.rot
    if rot == 0 then
        return wx - p.x0, wz - p.z0
    elseif rot == 1 then
        return p.z1 - wz, wx - p.x0
    elseif rot == 2 then
        return p.x1 - wx, p.z1 - wz
    end
    return wz - p.z0, p.x1 - wx
end

local plans = {}

function town.plan(cx, cz)
    local key = cx * 4096 + cz
    local plan = plans[key]
    if plan ~= nil then
        return plan or nil
    end
    local kind = town.lot_kind(cx, cz)
    if kind == nil or kind == "park" then
        plans[key] = false
        return nil
    end
    local def = reg().by_kind[kind]
    plan = {
        kind = kind, def = def, cx = cx, cz = cz, zone = town.zone(cx, cz), rot = 0,
        lot_w = town.LOT_SIZE, lot_d = town.LOT_SIZE,
    }
    def.plan(plan, function(n) return hash(cx, cz, n) end)
    plan.ox = plan.ox or math.floor((plan.lot_w - plan.w) / 2)
    plan.oz = plan.oz or 3
    plan.door = plan.door or math.floor(plan.w / 2)
    plan.x0 = cx * CELL + town.LOT_MIN + plan.ox
    plan.z0 = cz * CELL + town.LOT_MIN + plan.oz
    plan.x1 = plan.x0 + plan.w - 1
    plan.z1 = plan.z0 + plan.d - 1
    plans[key] = plan
    return plan
end

function town.find(kind)
    local best, best_d
    for cx = -R, R - 1 do
        for cz = -R, R - 1 do
            local p = town.plan(cx, cz)
            local d = math.abs(cx + 0.5) + math.abs(cz + 0.5)
            if p and p.kind == kind and (best == nil or d < best_d) then
                best, best_d = p, d
            end
        end
    end
    return best
end

function town.car_spot(p)
    if p == nil or p.car == nil then
        return nil
    end
    return town.to_world(p, p.car[1], p.car[2])
end

local ctx = {}

local function decorate(kind, zone, cx, cz, lx, lz, p, wx, wz, out)
    local list = reg().decor[zone]
    if list == nil then
        return
    end
    ctx.kind, ctx.zone, ctx.cx, ctx.cz, ctx.lx, ctx.lz, ctx.plan = kind, zone, cx, cz, lx, lz, p
    for _, d in ipairs(list) do
        if d.column(ctx, wx, wz, out) then
            return
        end
    end
end

local function surface(out, name, rot)
    table.insert(out, {0, name, rot or 0})
    table.insert(out, {1, "core:struct_air", 0})
end

function town.column(wx, wz, out)
    if not town.in_town(wx, wz) then
        if out then
            decorate("wild", "wild", nil, nil, nil, nil, nil, wx, wz, out)
        end
        return nil
    end
    local cx, cz, lx, lz = town.cell_at(wx, wz)
    local zone = town.zone(math.min(cx, R - 1), math.min(cz, R - 1))
    local road_x = lx < town.ROAD and cz >= -R and cz <= R and (cz < R or lz < town.ROAD)
    local road_z = lz < town.ROAD and cx >= -R and cx <= R and (cx < R or lx < town.ROAD)
    if road_x or road_z then
        if out then
            if road_x and not road_z and lx == 2 and wz % 6 < 3 then
                surface(out, "zomboid:road_line", 0)
            elseif road_z and not road_x and lz == 2 and wx % 6 < 3 then
                surface(out, "zomboid:road_line", 1)
            else
                surface(out, "zomboid:asphalt")
            end
            decorate("road", zone, cx, cz, lx, lz, nil, wx, wz, out)
        end
        return "road"
    end
    if cx >= R or cz >= R then
        return nil
    end
    if lx < town.LOT_MIN or lz < town.LOT_MIN or lx >= town.LOT_MIN + town.LOT_SIZE or lz >= town.LOT_MIN + town.LOT_SIZE then
        if out then
            surface(out, "zomboid:sidewalk")
            decorate("sidewalk", zone, cx, cz, lx, lz, nil, wx, wz, out)
        end
        return "sidewalk"
    end
    local p = town.plan(cx, cz)
    if p == nil then
        if out then
            decorate("park", zone, cx, cz, lx, lz, nil, wx, wz, out)
        end
        return "park"
    end
    local hx, hz = town.to_local(p, wx, wz)
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        if out then
            p.def.column(p, hx, hz, out)
        end
        return "building"
    end
    if out and p.car and hx == p.car[1] and hz == p.car[2] then
        table.insert(out, {1, "zomboid:car_spawner", 0})
    end
    if p.def.lot then
        local kind = p.def.lot(p, hx, hz, out)
        if kind then
            return kind
        end
    end
    if hx == p.door and hz < 0 then
        if out then
            surface(out, "zomboid:sidewalk")
        end
        return "path"
    end
    if out then
        decorate("lawn", zone, cx, cz, lx, lz, p, wx, wz, out)
    end
    return "lawn"
end

function town.building_at(wx, wz)
    if not town.in_town(wx, wz) then
        return nil
    end
    local p = town.plan(town.cell_at(wx, wz))
    if p == nil then
        return nil
    end
    local hx, hz = town.to_local(p, wx, wz)
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        return p.kind, p, hx, hz
    end
    return nil
end

function town.tree_at(wx, wz, seed)
    local kind = town.column(wx, wz)
    local r = hash(wx, wz, seed or 0)
    if kind == nil then
        local dist = math.max(math.abs(wx), math.abs(wz)) - CELL * R
        local chance = math.min(0.045, 0.004 + math.max(0, dist) * 0.0006)
        if r < chance then
            return math.floor(hash(wz, wx, 5) * 3)
        end
    elseif kind == "park" or kind == "lawn" then
        local cx, cz, lx, lz = town.cell_at(wx, wz)
        if lx < 9 or lz < 9 or lx > 27 or lz > 27 then
            return nil
        end
        local p = town.plan(cx, cz)
        if p then
            local hx, hz = town.to_local(p, wx, wz)
            if hx > -4 and hx < p.w + 3 and hz > -6 and hz < p.d + 3 then
                return nil
            end
        end
        if r < (kind == "park" and 0.02 or 0.006) then
            return math.floor(hash(wz, wx, 5) * 3)
        end
    end
    return nil
end

function town.house_interiors()
    local points = {}
    for cx = -R, R - 1 do
        for cz = -R, R - 1 do
            local p = town.plan(cx, cz)
            if p and p.kind == "house" then
                local x, z = town.to_world(p, p.mid, 2)
                table.insert(points, {x, GROUND + 1, z, dist = math.abs(cx + 0.5) + math.abs(cz + 0.5)})
            end
        end
    end
    table.sort(points, function(a, b) return a.dist < b.dist end)
    return points
end

function town.spawn_point(index)
    if world.get_generator() ~= "zomboid:town" then
        return nil
    end
    local points = town.house_interiors()
    local p = points[math.max(1, math.min(index or 1, #points))]
    return {p[1] + 0.5, p[2] + 0.95, p[3] + 0.5}
end

return town
