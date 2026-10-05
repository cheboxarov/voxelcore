local town = require "zomboid:town"

local util = {}

util.DIRS = {{0, -1}, {-1, 0}, {0, 1}, {1, 0}}
util.ZONES = {"downtown", "suburb", "industrial", "outskirts", "highway", "plaza", "park", "village"}

local cellmap

local AXES = {{1, 0, 0, 1}, {0, -1, 1, 0}, {-1, 0, 0, -1}, {0, 1, -1, 0}}

function util.key(x, z)
    return x * 65536 + z
end

function util.cell(cx, cz)
    if cellmap == nil then
        cellmap = {}
        for _, c in ipairs(town.cells()) do cellmap[util.key(c.cx, c.cz)] = c end
    end
    return cellmap[util.key(cx, cz)]
end

function util.run(x, z, dx, dz, kind, limit)
    local n = 0
    while n < limit and town.column(x + dx * n, z + dz * n) == kind do n = n + 1 end
    return n
end

function util.face(dx, dz)
    if dz < 0 then return 0 elseif dx < 0 then return 1 elseif dz > 0 then return 2 end
    return 3
end

function util.footprint(ox, oz, rot, sx, sz)
    local a = AXES[rot + 1]
    local cells = {}
    for i = 0, sx - 1 do
        for k = 0, sz - 1 do
            table.insert(cells, {ox + a[1] * i + a[3] * k, oz + a[2] * i + a[4] * k})
        end
    end
    return cells
end

function util.origin(minx, minz, rot, sx, sz)
    local mx, mz = 0, 0
    for _, c in ipairs(util.footprint(0, 0, rot, sx, sz)) do
        mx, mz = math.min(mx, c[1]), math.min(mz, c[2])
    end
    return minx - mx, minz - mz
end

function util.put(map, x, z, entries)
    local k = util.key(x, z)
    map[k] = map[k] or {}
    for _, e in ipairs(entries) do
        table.insert(map[k], e)
    end
end

function util.emit(map, wx, wz, out)
    local list = map[util.key(wx, wz)]
    if list == nil then
        return false
    end
    for _, e in ipairs(list) do
        table.insert(out, e)
    end
    return true
end

function util.wide(map, name, ox, oz, rot, sx, sz)
    util.put(map, ox, oz, {{1, name, rot, 3}})
    local cells = util.footprint(ox, oz, rot, sx, sz)
    if name:find("wreck") or name:find("dumpster") then
        for _, c in ipairs(cells) do
            util.put(map, c[1], c[2], {{2, "zomboid:decor_collider", 0, 3}})
        end
    end
    return cells
end

function util.lamp(rot)
    return {{1, "zomboid:decor_pole", 0}, {2, "zomboid:decor_pole", 0}, {3, "zomboid:decor_pole", 0},
            {4, "zomboid:decor_streetlight", rot}}
end

function util.decal(name, r)
    return {{1, "zomboid:decor_" .. name, math.floor(r * 4) % 4}}
end

return util
