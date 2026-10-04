local town = {}

town.GROUND = 40
town.SEA_LEVEL = 38
town.FLAT_EXTENT = 250
town.CENTER = {-18, 0}
town.HIGHWAY_HALF = 4

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

local PARK_WEIGHT = {downtown = 2, suburb = 8, outskirts = 22, industrial = 6, highway = 2, village = 0}

local registry

local function reg()
    if registry then
        return registry
    end
    registry = {list = load_dir("buildings"), by_kind = {}, pick = {}, decor = {}}
    for _, def in ipairs(registry.list) do
        registry.by_kind[def.kind] = def
        for _, zone in ipairs(def.zones or {}) do
            local w = type(def.weight) == "table" and def.weight[zone] or def.weight or 1
            local key = zone .. ":" .. (def.cells or 1)
            registry.pick[key] = registry.pick[key] or {}
            table.insert(registry.pick[key], {def.kind, w})
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

-- Street grids: alternating line/cell widths, line segments and cell zones by map indices (even = line, odd = cell).
local ZONE_OF = {D = "downtown", S = "suburb", I = "industrial", O = "outskirts", H = "highway", P = "plaza", K = "park", V = "village"}
local SIDEWALK = {downtown = true, suburb = true, industrial = true, plaza = true, park = true}

local GRIDS = {
    {
        name = "town", x0 = -243, z0 = -192, cx0 = -7, cz0 = -6,
        xs = {5, 32, 5, 28, 5, 28, 5, 28, 5, 24, 3, 24, 5, 24, 9, 24, 5, 24, 21, 36, 5, 36, 5, 34, 5},
        zs = {5, 32, 5, 28, 5, 28, 5, 24, 3, 24, 5, 24, 9, 24, 5, 24, 3, 24, 5, 28, 5, 28, 5, 32, 5},
        v = {
            [0] = {{8, 16, "#"}}, [2] = {{4, 22, "#"}}, [4] = {{4, 12, "#"}, {20, 22, "#"}}, [6] = {{0, 24, "#"}},
            [8] = {{2, 22, "#"}}, [10] = {{6, 14, "a"}}, [12] = {{4, 20, "#"}}, [14] = {{0, 10, "#"}, {11, 13, "p"}, {14, 24, "#"}},
            [16] = {{4, 22, "#"}}, [18] = {{0, 24, "~"}}, [20] = {{6, 12, "#"}}, [22] = {{6, 18, "#"}}, [24] = {{10, 14, "#"}},
        },
        h = {
            [0] = {{6, 14, "#"}}, [2] = {{4, 14, "#"}}, [4] = {{2, 16, "#"}}, [6] = {{0, 24, "#"}},
            [8] = {{8, 16, "a"}}, [10] = {{4, 16, "#"}}, [12] = {{0, 12, "#"}, {13, 15, "p"}, {16, 24, "#"}},
            [14] = {{2, 16, "#"}}, [16] = {{12, 16, "a"}}, [18] = {{0, 24, "#"}}, [20] = {{2, 16, "#"}},
            [22] = {{4, 14, "#"}}, [24] = {{6, 14, "#"}},
        },
        zones = {
            {1, 23, 1, 23, "S"},
            {9, 17, 7, 17, "D"},
            {19, 21, 3, 21, "I"},
            {1, 1, 3, 21, "O"}, {23, 23, 3, 21, "O"}, {5, 17, 1, 1, "O"}, {5, 15, 23, 23, "O"},
            {1, 1, 11, 13, "H"}, {23, 23, 11, 13, "H"},
            {13, 15, 11, 13, "P"},
            {5, 5, 9, 9, "K"}, {17, 17, 3, 3, "K"},
            {1, 3, 1, 1, "."}, {1, 1, 3, 3, "."}, {19, 23, 1, 1, "."}, {23, 23, 3, 3, "."},
            {1, 3, 23, 23, "."}, {1, 1, 21, 21, "."}, {17, 23, 23, 23, "."}, {23, 23, 21, 21, "."},
        },
        groups = {{19, 3}, {19, 13}, {19, 19}, {3, 15}, {9, 15}},
        forced = {["11:11"] = "police", ["11:13"] = "grocery", ["17:9"] = "pharmacy", ["23:13"] = "gas_station"},
    },
    {
        name = "village", x0 = 560, z0 = -37, cx0 = 100, cz0 = 0,
        xs = {5, 30, 5, 30, 5, 30, 5},
        zs = {5, 28, 9, 28, 5},
        v = {[2] = {{0, 2, "#"}}, [4] = {{2, 4, "#"}}},
        h = {[2] = {{0, 6, "#"}}},
        zones = {{1, 5, 1, 3, "V"}},
        groups = {},
        forced = {["5:3"] = "gas_station", ["3:1"] = "church"},
    },
}

local function prefix(list, start)
    local pos, idx, off = {}, {}, {}
    local x = start
    for i, w in ipairs(list) do
        pos[i - 1] = x
        for k = 0, w - 1 do
            idx[x + k - start] = i - 1
            off[x + k - start] = k
        end
        x = x + w
    end
    return pos, idx, off, x - 1
end

local function seg_type(lines, line, at)
    for _, s in ipairs(lines[line] or {}) do
        if at >= s[1] and at <= s[2] then
            return s[3]
        end
    end
    return nil
end

local cells = {}
local cell_list = {}
local crossings = {}

local function cell_key(cx, cz)
    return cx * 4096 + cz
end

for _, g in ipairs(GRIDS) do
    g.px, g.ix, g.ox, g.x1 = prefix(g.xs, g.x0)
    g.pz, g.iz, g.oz, g.z1 = prefix(g.zs, g.z0)
    g.nc, g.nr = #g.xs - 1, #g.zs - 1
    g.zone = {}
    for _, z in ipairs(g.zones) do
        for c = z[1], z[2], 2 do
            for r = z[3], z[4], 2 do
                g.zone[c * 64 + r] = z[5]
            end
        end
    end
    g.group = {}
    for _, a in ipairs(g.groups) do
        for dc = 0, 2, 2 do
            for dr = 0, 2, 2 do
                g.group[(a[1] + dc) * 64 + a[2] + dr] = a
            end
        end
    end
end

-- Line/crossing type at map index (col, row): "#", "a", "p", "~", "=" (bridge), " " (yard strip) or "." (wild).
local function line_type(g, col, row)
    local vert = col % 2 == 0
    local horiz = row % 2 == 0
    local v = vert and seg_type(g.v, col, row)
    local h = horiz and seg_type(g.h, row, col)
    if v == "~" then
        return (h == "#") and "=" or "~"
    end
    local t = v or h
    if vert and horiz and v and h and v ~= h then
        t = (v == "#" or h == "#") and "#" or v
    end
    if t then
        return t
    end
    local function filled(c, r)
        return c >= 1 and r >= 1 and c < g.nc and r < g.nr and (g.zone[c * 64 + r] or ".") ~= "."
    end
    local any
    if vert and horiz then
        any = filled(col - 1, row - 1) or filled(col + 1, row - 1) or filled(col - 1, row + 1) or filled(col + 1, row + 1)
    elseif vert then
        any = filled(col - 1, row) or filled(col + 1, row)
    else
        any = filled(col, row - 1) or filled(col, row + 1)
    end
    return any and " " or "."
end

local SIDES = {{0, -1}, {-1, 0}, {0, 1}, {1, 0}}

for _, g in ipairs(GRIDS) do
    g.lines = {}
    for col = 0, g.nc do
        for row = 0, g.nr do
            if col % 2 == 0 or row % 2 == 0 then
                g.lines[col * 64 + row] = line_type(g, col, row)
            end
        end
    end
    for col = 1, g.nc - 1, 2 do
        for row = 1, g.nr - 1, 2 do
            local ch = g.zone[col * 64 + row] or "."
            if ch ~= "." then
                local cx, cz = g.cx0 + (col - 1) / 2, g.cz0 + (row - 1) / 2
                local c = {
                    g = g, col = col, row = row, cx = cx, cz = cz, zone = ZONE_OF[ch],
                    x0 = g.px[col], z0 = g.pz[row], x1 = g.px[col + 1] - 1, z1 = g.pz[row + 1] - 1,
                    group = g.group[col * 64 + row],
                }
                cells[cell_key(cx, cz)] = c
                table.insert(cell_list, c)
            end
        end
    end
    for col = 0, g.nc, 2 do
        for row = 0, g.nr, 2 do
            local t = g.lines[col * 64 + row]
            if t == "#" or t == "=" then
                local node = {
                    x = g.px[col] + math.floor(g.xs[col + 1] / 2), z = g.pz[row] + math.floor(g.zs[row + 1] / 2),
                    g = g, col = col, row = row, links = {},
                }
                crossings[g.name .. col * 64 + row] = node
            end
        end
    end
    for _, node in pairs(crossings) do
        if node.g == g then
            for _, s in ipairs(SIDES) do
                local seg = g.lines[(node.col + s[1]) * 64 + node.row + s[2]]
                local other = crossings[g.name .. (node.col + 2 * s[1]) * 64 + node.row + 2 * s[2]]
                if (seg == "#" or seg == "=") and other then
                    table.insert(node.links, other)
                end
            end
        end
    end
end

town.BOUNDS = {GRIDS[1].x0, GRIDS[1].z0, GRIDS[1].x1, GRIDS[1].z1}
for _, g in ipairs(GRIDS) do
    local b = town.BOUNDS
    b[1], b[2], b[3], b[4] = math.min(b[1], g.x0), math.min(b[2], g.z0), math.max(b[3], g.x1), math.max(b[4], g.z1)
end

local function locate(wx, wz)
    for _, g in ipairs(GRIDS) do
        if wx >= g.x0 and wx <= g.x1 and wz >= g.z0 and wz <= g.z1 then
            return g, g.ix[wx - g.x0], g.iz[wz - g.z0], g.ox[wx - g.x0], g.oz[wz - g.z0]
        end
    end
    return nil
end

function town.in_town(wx, wz)
    return locate(wx, wz) ~= nil
end

function town.highway_z(wx)
    if wx > 181 and wx < 560 then
        return 40 * math.sin(math.pi * (wx - 181) / 379) ^ 2
    elseif wx >= 670 then
        return 30 * math.sin(math.pi * (wx - 670) / 300) ^ 2
    elseif wx < -243 then
        return -35 * math.sin(math.pi * (wx + 243) / 260) ^ 2
    end
    return 0
end

function town.flat_dist(wx, wz)
    local best = math.abs(wz - town.highway_z(wx)) - town.HIGHWAY_HALF
    for _, g in ipairs(GRIDS) do
        local dx = math.max(g.x0 - wx, 0, wx - g.x1)
        local dz = math.max(g.z0 - wz, 0, wz - g.z1)
        best = math.min(best, math.sqrt(dx * dx + dz * dz))
    end
    return math.max(0, best)
end

function town.cells()
    return cell_list
end

function town.cell_center(cx, cz)
    local c = cells[cell_key(cx, cz)]
    return c and math.floor((c.x0 + c.x1) / 2), c and math.floor((c.z0 + c.z1) / 2)
end

function town.zone(cx, cz)
    local c = cells[cell_key(cx, cz)]
    return c and c.zone
end

function town.cell_at(wx, wz)
    local g, col, row, ox, oz = locate(wx, wz)
    if g == nil or col % 2 == 0 or row % 2 == 0 then
        return nil
    end
    return g.cx0 + (col - 1) / 2, g.cz0 + (row - 1) / 2, ox, oz
end

function town.crossing_near(wx, wz)
    local best, best_d
    for _, node in pairs(crossings) do
        local d = (node.x - wx) ^ 2 + (node.z - wz) ^ 2
        if best == nil or d < best_d then
            best, best_d = node, d
        end
    end
    return best
end

local function weighted(options, extra, r)
    local total = extra
    for _, o in ipairs(options) do total = total + o[2] end
    r = r * total
    for _, o in ipairs(options) do
        r = r - o[2]
        if r < 0 then
            return o[1]
        end
    end
    return nil
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

-- Lot of a cell or a 2x2 group: the area inside the sidewalks and the side that faces the widest road.
local function make_lot(g, col0, row0, col1, row1, zone, seed)
    local lot = {x0 = g.px[col0], z0 = g.pz[row0], x1 = g.px[col1 + 1] - 1, z1 = g.pz[row1 + 1] - 1, sides = {}}
    local best, best_w = nil, -1
    for i, s in ipairs(SIDES) do
        local road = false
        local width
        if s[1] == 0 then
            local row = s[2] < 0 and row0 - 1 or row1 + 1
            width = g.zs[row + 1]
            for col = col0, col1, 2 do
                if g.lines[col * 64 + row] == "#" or g.lines[col * 64 + row] == "=" then road = true end
            end
        else
            local col = s[1] < 0 and col0 - 1 or col1 + 1
            width = g.xs[col + 1]
            for row = row0, row1, 2 do
                if g.lines[col * 64 + row] == "#" or g.lines[col * 64 + row] == "=" then road = true end
            end
        end
        lot.sides[i] = road
        local score = road and width + hash(seed, i, 41) or -1
        if road and score > best_w then
            best, best_w = i, score
        end
    end
    if SIDEWALK[zone] then
        if lot.sides[1] then lot.z0 = lot.z0 + 2 end
        if lot.sides[2] then lot.x0 = lot.x0 + 2 end
        if lot.sides[3] then lot.z1 = lot.z1 - 2 end
        if lot.sides[4] then lot.x1 = lot.x1 - 2 end
    end
    lot.rot = best and best - 1
    return lot
end

local function lot_of(c)
    if c.lot == nil then
        c.lot = make_lot(c.g, c.col, c.row, c.col, c.row, c.zone, c.cx * 131 + c.cz)
    end
    return c.lot
end

local function place(p, def, lot, seed)
    local rot = lot.rot
    p.rot = rot
    if rot == 0 or rot == 2 then
        p.lot_w, p.lot_d = lot.x1 - lot.x0 + 1, lot.z1 - lot.z0 + 1
    else
        p.lot_w, p.lot_d = lot.z1 - lot.z0 + 1, lot.x1 - lot.x0 + 1
    end
    def.plan(p, function(n) return hash(seed, n, 7) end)
    if p.w > p.lot_w or p.d > p.lot_d then
        return false
    end
    p.ox = p.ox or math.floor((p.lot_w - p.w) / 2)
    p.oz = math.min(p.oz or (p.zone == "downtown" and 1 or 3), p.lot_d - p.d)
    p.door = p.door or math.floor(p.w / 2)
    local w, d, ox, oz = p.w, p.d, p.ox, p.oz
    if rot == 0 then
        p.x0, p.z0 = lot.x0 + ox, lot.z0 + oz
        p.x1, p.z1 = p.x0 + w - 1, p.z0 + d - 1
    elseif rot == 2 then
        p.x1, p.z1 = lot.x1 - ox, lot.z1 - oz
        p.x0, p.z0 = p.x1 - w + 1, p.z1 - d + 1
    elseif rot == 1 then
        p.x0, p.z1 = lot.x0 + oz, lot.z1 - ox
        p.x1, p.z0 = p.x0 + d - 1, p.z1 - w + 1
    else
        p.x1, p.z0 = lot.x1 - oz, lot.z0 + ox
        p.x0, p.z1 = p.x1 - d + 1, p.z0 + w - 1
    end
    p.lot = lot
    if p.car then
        local cx, cz = town.to_world(p, p.car[1], p.car[2])
        local inside = p.car[1] >= 0 and p.car[1] < w and p.car[2] >= 0 and p.car[2] < d
        if inside or cx < lot.x0 or cx > lot.x1 or cz < lot.z0 or cz > lot.z1 then
            p.car = nil
        end
    end
    return true
end

local function try_plan(c, kind, lot, cells_n, seed)
    local def = kind and reg().by_kind[kind]
    if def == nil or lot.rot == nil then
        return nil
    end
    local p = {kind = kind, def = def, cx = c.cx, cz = c.cz, zone = c.zone, cells = cells_n}
    if place(p, def, lot, seed) then
        return p
    end
    return nil
end

local function plan_group(c)
    local a = c.group
    local g = c.g
    local anchor = cells[cell_key(g.cx0 + (a[1] - 1) / 2, g.cz0 + (a[2] - 1) / 2)]
    if anchor.group_plan == nil then
        local seed = anchor.cx * 131 + anchor.cz
        local kind = weighted(reg().pick[anchor.zone .. ":2"] or {}, 0, hash(seed, 0, 29))
        local lot = make_lot(g, a[1], a[2], a[1] + 2, a[2] + 2, anchor.zone, seed)
        anchor.group_plan = try_plan(anchor, kind, lot, 2, seed) or false
        if anchor.group_plan then
            anchor.group_plan.group = a
        end
    end
    return anchor.group_plan
end

function town.lot_kind(cx, cz)
    local c = cells[cell_key(cx, cz)]
    if c == nil then
        return nil
    end
    if c.zone == "plaza" or c.zone == "park" then
        return c.zone
    end
    local forced = c.g.forced[c.col .. ":" .. c.row]
    if forced and reg().by_kind[forced] then
        return forced
    end
    return weighted(reg().pick[c.zone .. ":1"] or {}, PARK_WEIGHT[c.zone] or 0, hash(cx, cz, 17)) or "park"
end

function town.plan(cx, cz)
    local c = cells[cell_key(cx, cz)]
    if c == nil then
        return nil
    end
    if c.plan == nil then
        local p = c.group and plan_group(c)
        local kind = not p and town.lot_kind(cx, cz)
        if kind and reg().by_kind[kind] then
            p = try_plan(c, kind, lot_of(c), 1, cx * 131 + cz) or try_plan(c, "house", lot_of(c), 1, cx * 131 + cz)
        end
        c.plan = p or false
    end
    return c.plan or nil
end

function town.find(kind)
    local best, best_d
    for _, c in ipairs(cell_list) do
        local p = town.plan(c.cx, c.cz)
        if p and p.kind == kind then
            local x, z = town.to_world(p, p.door, 0)
            local d = math.abs(x - town.CENTER[1]) + math.abs(z - town.CENTER[2])
            if best == nil or d < best_d then
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

local profiles = {}

local function rotate_entries(out, from, rot)
    for i = from, #out do
        local e = out[i]
        local name = e[2]
        local prof = profiles[name]
        if prof == nil then
            prof = block.get_rotation_profile(block.index(name))
            profiles[name] = prof
        end
        if prof == "pane" then
            e[3] = (e[3] + rot) % 4
        elseif prof == "pipe" and e[3] < 4 then
            e[3] = (e[3] - rot) % 4
        end
    end
end

local ctx = {}

local function decorate(kind, zone, c, lx, lz, p, wx, wz, out)
    local list = reg().decor[zone]
    if list == nil then
        return
    end
    ctx.kind, ctx.zone, ctx.cx, ctx.cz, ctx.lx, ctx.lz, ctx.plan = kind, zone, c and c.cx, c and c.cz, lx, lz, p
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

local function highway(wx, wz, out)
    local hz = town.highway_z(wx)
    if math.abs(wz - hz) > town.HIGHWAY_HALF + 0.5 then
        return nil
    end
    if out then
        if wz == math.floor(hz + 0.5) and wx % 6 < 3 then
            surface(out, "zomboid:road_line", 1)
        else
            surface(out, "zomboid:asphalt")
        end
    end
    return "road"
end

local function fountain(dx, dz, out)
    local r2 = dx * dx + dz * dz
    if r2 <= 1 then
        table.insert(out, {0, "base:stone", 0})
        for dy = 1, 3 do table.insert(out, {dy, "base:stone", 0}) end
        table.insert(out, {4, "base:metal", 0})
        return true
    elseif r2 <= 8 then
        table.insert(out, {-1, "base:stone", 0})
        table.insert(out, {0, "base:water", 0})
        table.insert(out, {1, "core:struct_air", 0})
        return true
    elseif r2 <= 13 then
        table.insert(out, {0, "base:stone", 0})
        table.insert(out, {1, "base:stone", 0})
        return true
    end
    return false
end

local function river(ox, oz, horizontal_road, width, wx, wz, out)
    local bank = ox <= 2 or ox >= 18
    if horizontal_road then
        if out then
            if not bank then
                table.insert(out, {-7, "base:sand", 0})
                for dy = -6, -2 do table.insert(out, {dy, "base:water", 0}) end
                table.insert(out, {-1, "core:struct_air", 0})
            end
            local mid = math.floor(width / 2)
            if oz == mid and wx % 6 < 3 then
                surface(out, "zomboid:road_line", 1)
            else
                surface(out, "zomboid:asphalt")
            end
            if (oz == 0 or oz == width - 1) and ox >= 2 and ox <= 18 then
                out[#out][2] = "zomboid:layout_railing"
            end
        end
        return "bridge"
    end
    if out then
        local exit = wz % 40 == 20
        if bank then
            for dy = -6, -1 do table.insert(out, {dy, "base:stone", 0}) end
            surface(out, "zomboid:sidewalk")
            if (ox == 2 or ox == 18) and not exit then
                out[#out][2] = "zomboid:layout_railing"
            end
        elseif exit and (ox == 3 or ox == 17) then
            table.insert(out, {-7, "base:sand", 0})
            for dy = -6, 0 do table.insert(out, {dy, "zomboid:ladder", ox == 3 and 3 or 1}) end
            table.insert(out, {1, "core:struct_air", 0})
        else
            table.insert(out, {-7, "base:sand", 0})
            for dy = -6, -2 do table.insert(out, {dy, "base:water", 0}) end
            for dy = -1, 1 do table.insert(out, {dy, "core:struct_air", 0}) end
        end
    end
    return bank and "sidewalk" or "river"
end

local function line_zone(g, col, row)
    for _, d in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, 1}, {-1, 1}, {1, -1}}) do
        local z = g.zone[(col + d[1]) * 64 + row + d[2]]
        if z and z ~= "." then
            return ZONE_OF[z]
        end
    end
    return "wild"
end

local function group_plan_at(g, col, row)
    local vert, horiz = col % 2 == 0, row % 2 == 0
    local c1 = vert and g.group[(col - 1) * 64 + row - (horiz and 1 or 0)] or g.group[col * 64 + row - 1]
    local c2 = vert and g.group[(col + 1) * 64 + row + (horiz and 1 or 0)] or g.group[col * 64 + row + 1]
    if c1 == nil or c1 ~= c2 then
        return nil
    end
    local c = cells[cell_key(g.cx0 + (c1[1] - 1) / 2, g.cz0 + (c1[2] - 1) / 2)]
    return plan_group(c) or nil
end

local function lot_column(c, p, lot, wx, wz, out)
    local zone = c.zone
    if p == nil then
        if zone == "plaza" then
            local cx, cz = (lot.x0 + lot.x1) / 2, (lot.z0 + lot.z1) / 2
            local inner = math.abs(wx - cx) < (lot.x1 - lot.x0) / 2 - 2 and math.abs(wz - cz) < (lot.z1 - lot.z0) / 2 - 2
            if inner then
                if out then decorate("park", zone, c, wx - c.x0, wz - c.z0, nil, wx, wz, out) end
                return "park"
            end
            if out then
                surface(out, "zomboid:sidewalk")
                decorate("plaza", zone, c, wx - c.x0, wz - c.z0, nil, wx, wz, out)
            end
            return "plaza"
        end
        if out then decorate("park", zone, c, wx - c.x0, wz - c.z0, nil, wx, wz, out) end
        return "park"
    end
    local hx, hz = town.to_local(p, wx, wz)
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        if out then
            local from = #out + 1
            p.def.column(p, hx, hz, out)
            if p.rot ~= 0 then
                rotate_entries(out, from, p.rot)
            end
        end
        return "building"
    end
    local car = p.car and hx == p.car[1] and hz == p.car[2]
    if out and car then
        table.insert(out, {1, "zomboid:car_spawner", 0})
    end
    if p.def.lot then
        local from = out and #out + 1
        local kind = p.def.lot(p, hx, hz, out)
        if kind then
            if out and p.rot ~= 0 then
                rotate_entries(out, from, p.rot)
            end
            return kind
        end
    end
    if hx == p.door and hz < 0 then
        if out then
            surface(out, "zomboid:sidewalk")
        end
        return "path"
    end
    if out and not car then
        decorate("lawn", zone, c, wx - c.x0, wz - c.z0, p, wx, wz, out)
    end
    return "lawn"
end

function town.column(wx, wz, out)
    local g, col, row, ox, oz = locate(wx, wz)
    if g == nil then
        local kind = highway(wx, wz, out)
        if out then
            decorate(kind or "wild", kind and "highway" or "wild", nil, nil, nil, nil, wx, wz, out)
        end
        return kind
    end
    if col % 2 == 0 or row % 2 == 0 then
        local t = g.lines[col * 64 + row]
        if t == "." then
            local kind = highway(wx, wz, out)
            if out then
                decorate(kind or "wild", kind and "highway" or "wild", nil, nil, nil, nil, wx, wz, out)
            end
            return kind
        end
        local zone = line_zone(g, col, row)
        if t == "~" or t == "=" then
            return river(ox, oz, t == "=", g.zs[row + 1], wx, wz, out)
        elseif t == "#" or t == "a" then
            if out then
                local vert = col % 2 == 0
                local w = vert and g.xs[col + 1] or g.zs[row + 1]
                local o = vert and ox or oz
                local crossing = col % 2 == 0 and row % 2 == 0
                if t == "#" and not crossing and o == math.floor(w / 2) and (vert and wz or wx) % 6 < 3 then
                    surface(out, "zomboid:road_line", vert and 0 or 1)
                else
                    surface(out, "zomboid:asphalt")
                end
                decorate("road", zone, nil, ox, oz, nil, wx, wz, out)
            end
            return "road"
        elseif t == "p" then
            if out then
                local cx = g.px[14] + math.floor(g.xs[15] / 2)
                local cz = g.pz[12] + math.floor(g.zs[13] / 2)
                if not fountain(wx - cx, wz - cz, out) then
                    surface(out, (wx + wz) % 2 == 0 and "zomboid:sidewalk" or "zomboid:tiles")
                    decorate("plaza", "plaza", nil, ox, oz, nil, wx, wz, out)
                end
            end
            return "plaza"
        end
        local p = group_plan_at(g, col, row)
        local walk = zone == "downtown" or zone == "plaza"
        if p then
            local lot = p.lot
            if wx >= lot.x0 and wx <= lot.x1 and wz >= lot.z0 and wz <= lot.z1 then
                return lot_column(cells[cell_key(p.cx, p.cz)], p, lot, wx, wz, out)
            end
            walk = true
        elseif SIDEWALK[zone] and not walk then
            local function road(c2, r2)
                local t2 = g.lines[c2 * 64 + r2]
                return t2 == "#" or t2 == "="
            end
            if col % 2 == 0 and row % 2 == 1 then
                walk = (oz < 2 and road(col, row - 1)) or (oz >= g.zs[row + 1] - 2 and road(col, row + 1))
            elseif row % 2 == 0 and col % 2 == 1 then
                walk = (ox < 2 and road(col - 1, row)) or (ox >= g.xs[col + 1] - 2 and road(col + 1, row))
            end
        end
        if walk then
            if out then
                surface(out, "zomboid:sidewalk")
                decorate("sidewalk", zone, nil, ox, oz, nil, wx, wz, out)
            end
            return "sidewalk"
        end
        if out then
            local fence = zone == "suburb" or zone == "outskirts" or zone == "village"
            local on_x = col % 2 == 0 and ox == math.floor(g.xs[col + 1] / 2)
            local on_z = row % 2 == 0 and oz == math.floor(g.zs[row + 1] / 2)
            if fence and (on_x or on_z) then
                table.insert(out, {1, "zomboid:layout_fence", 0})
            else
                decorate("lawn", zone, nil, ox, oz, nil, wx, wz, out)
            end
        end
        return "lawn"
    end
    local c = cells[cell_key(g.cx0 + (col - 1) / 2, g.cz0 + (row - 1) / 2)]
    if c == nil then
        local kind = highway(wx, wz, out)
        if out then
            decorate(kind or "wild", kind and "highway" or "wild", nil, nil, nil, nil, wx, wz, out)
        end
        return kind
    end
    local p = town.plan(c.cx, c.cz)
    local lot = p and p.lot or lot_of(c)
    if wx < lot.x0 or wx > lot.x1 or wz < lot.z0 or wz > lot.z1 then
        if out then
            surface(out, "zomboid:sidewalk")
            decorate("sidewalk", c.zone, c, ox, oz, nil, wx, wz, out)
        end
        return "sidewalk"
    end
    return lot_column(c, p, lot, wx, wz, out)
end

function town.building_at(wx, wz)
    local g, col, row = locate(wx, wz)
    if g == nil then
        return nil
    end
    local p
    if col % 2 == 1 and row % 2 == 1 then
        local c = cells[cell_key(g.cx0 + (col - 1) / 2, g.cz0 + (row - 1) / 2)]
        p = c and town.plan(c.cx, c.cz)
    else
        p = group_plan_at(g, col, row)
    end
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
        local dist = town.flat_dist(wx, wz)
        if dist > 2 and r < math.min(0.045, 0.004 + dist * 0.0006) then
            return math.floor(hash(wz, wx, 5) * 3)
        end
    elseif kind == "park" or kind == "lawn" then
        local cx, cz, lx, lz = town.cell_at(wx, wz)
        if cx == nil then
            return nil
        end
        local c = cells[cell_key(cx, cz)]
        if lx < 4 or lz < 4 or c.x1 - wx < 4 or c.z1 - wz < 4 then
            return nil
        end
        local p = town.plan(cx, cz)
        if p then
            local hx, hz = town.to_local(p, wx, wz)
            if hx > -4 and hx < p.w + 3 and hz > -6 and hz < p.d + 3 then
                return nil
            end
        end
        local chance = kind == "park" and 0.02 or 0.006
        if c.zone == "outskirts" then
            chance = chance * 2
        end
        if r < chance then
            return math.floor(hash(wz, wx, 5) * 3)
        end
    end
    return nil
end

function town.house_interiors()
    local points = {}
    for _, c in ipairs(cell_list) do
        local p = town.plan(c.cx, c.cz)
        if p and p.kind == "house" and p.rot == 0 and p.cx == c.cx and p.cz == c.cz then
            local x, z = town.to_world(p, p.mid, 2)
            local dist = math.abs(x - town.CENTER[1]) + math.abs(z - town.CENTER[2])
            table.insert(points, {x, GROUND + 1, z, dist = dist})
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
