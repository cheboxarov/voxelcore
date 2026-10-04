-- Deterministic town plan shared by the world generator and runtime logic.
local town = {}

town.GROUND = 40
town.SEA_LEVEL = 38
town.CELL = 32
town.RADIUS = 3
town.ROAD = 5
town.LOT_MIN = 7
town.LOT_MAX = 29
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

local function cell_of(w)
    return math.floor(w / CELL), w % CELL
end

function town.in_town(wx, wz)
    local limit = CELL * R + town.ROAD
    return wx >= -CELL * R and wx < limit and wz >= -CELL * R and wz < limit
end

local SIDINGS = {"siding_white", "siding_blue", "siding_yellow", "siding_green", "siding_red"}

-- Lot kind of the cell: house, grocery, hardware, pharmacy, police, park.
function town.lot_kind(cx, cz)
    if cx < -R or cz < -R or cx >= R or cz >= R then
        return nil
    end
    if cx == 0 and cz == 0 then
        return "house"
    end
    if cx == -1 and cz == 0 then
        return "grocery"
    end
    local r = hash(cx, cz, 17)
    if r < 0.08 then return "grocery"
    elseif r < 0.15 then return "hardware"
    elseif r < 0.21 then return "pharmacy"
    elseif r < 0.26 then return "police"
    elseif r < 0.38 then return "park"
    end
    return "house"
end

local plans = {}

-- Building plan inside the lot (lot-local x,z -> footprint).
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
    local w, d, wall
    if kind == "house" then
        w = 9 + 2 * math.floor(hash(cx, cz, 1) * 3)
        d = 9 + 2 * math.floor(hash(cx, cz, 2) * 3)
        wall = SIDINGS[1 + math.floor(hash(cx, cz, 3) * #SIDINGS)]
    else
        w, d, wall = 17, 13, kind == "police" and "base:stone" or "base:brick"
    end
    plan = {
        kind = kind,
        w = w, d = d,
        x0 = town.LOT_MIN + math.floor((23 - w) / 2),
        z0 = town.LOT_MIN + 3,
        wall = wall,
        mid = math.floor(w / 2),
        split = math.floor(d / 2),
    }
    plan.door = plan.mid
    plans[key] = plan
    return plan
end

-- Column contents: list of {dy, block_name, rotation}; dy is relative to GROUND.
local function house_column(p, hx, hz, out)
    local w, d = p.w, p.d
    local wall = p.wall
    if wall:find(":") == nil then
        wall = "zomboid:" .. wall
    end
    local edge_x = hx == 0 or hx == w - 1
    local edge_z = hz == 0 or hz == d - 1
    local perimeter = edge_x or edge_z
    local corner = edge_x and edge_z
    local back_door = 1

    local floor = "base:planks"
    if not perimeter then
        if hz > p.split and hx < p.mid then
            floor = "zomboid:tiles"
        elseif hz > p.split and hx > p.mid then
            floor = "zomboid:carpet"
        end
    end
    table.insert(out, {0, floor, 0})
    table.insert(out, {4, "zomboid:roof", 0})
    if perimeter then
        table.insert(out, {5, "zomboid:trim", 0})
    end

    if corner then
        for dy = 1, 3 do table.insert(out, {dy, "zomboid:trim", 0}) end
        return
    end
    if perimeter then
        if hz == 0 and hx == p.door then
            table.insert(out, {1, "base:wooden_door", 0})
            table.insert(out, {3, wall, 0})
            return
        end
        if hz == d - 1 and hx == back_door then
            table.insert(out, {1, "base:wooden_door", 0})
            table.insert(out, {3, wall, 0})
            return
        end
        local along = edge_z and hx or hz
        local near_door = edge_z and (math.abs(hx - p.door) <= 1 and hz == 0 or math.abs(hx - back_door) <= 1 and hz == d - 1)
        if along % 3 == 1 and not near_door then
            table.insert(out, {1, "zomboid:window", 0})
            table.insert(out, {2, "zomboid:window", 0})
        else
            table.insert(out, {1, wall, 0})
            table.insert(out, {2, wall, 0})
        end
        table.insert(out, {3, wall, 0})
        return
    end
    -- interior partitions
    if hz == p.split then
        if hx == 2 or hx == w - 3 then
            table.insert(out, {1, "core:struct_air", 0})
            table.insert(out, {2, "core:struct_air", 0})
        else
            table.insert(out, {1, "zomboid:siding_white", 0})
            table.insert(out, {2, "zomboid:siding_white", 0})
        end
        table.insert(out, {3, "zomboid:siding_white", 0})
        return
    end
    if hx == p.mid and hz > p.split then
        for dy = 1, 3 do table.insert(out, {dy, "zomboid:siding_white", 0}) end
        return
    end
    -- furniture
    local furniture
    local rot = 0
    if hz == d - 2 and hx < p.mid and hx >= 2 then
        if hx == p.mid - 1 then furniture = "zomboid:fridge"
        elseif hx == 2 then furniture = "zomboid:sink"
        elseif hx == 3 then furniture = "zomboid:stove"
        else furniture = "zomboid:kitchen_cabinet" end
        rot = 2
    elseif hz == d - 2 and (hx == w - 2 or hx == w - 3) then
        furniture, rot = "zomboid:bed", 2
    elseif hz == d - 2 and hx == p.mid + 1 then
        furniture, rot = "zomboid:wardrobe", 2
    elseif hx == w - 2 and hz == p.split + 1 then
        furniture, rot = "zomboid:medicine_cabinet", 3
    elseif hx == w - 2 and (hz == 2 or hz == 3) then
        furniture, rot = "zomboid:couch", 3
    elseif hx == 1 and hz == 2 then
        furniture, rot = "zomboid:crate", 1
    elseif hx == 1 and hz == p.split - 1 then
        furniture, rot = "zomboid:wardrobe", 1
    end
    if furniture then
        table.insert(out, {1, furniture, rot})
        if furniture ~= "zomboid:fridge" and furniture ~= "zomboid:wardrobe" then
            table.insert(out, {2, "core:struct_air", 0})
        end
    else
        table.insert(out, {1, "core:struct_air", 0})
        table.insert(out, {2, "core:struct_air", 0})
    end
    table.insert(out, {3, "core:struct_air", 0})
end

local STORE_CONTAINER = {
    grocery = "zomboid:shelf",
    hardware = "zomboid:crate",
    pharmacy = "zomboid:medicine_cabinet",
    police = "zomboid:crate",
}

local function store_column(p, hx, hz, out)
    local w, d = p.w, p.d
    local edge_x = hx == 0 or hx == w - 1
    local edge_z = hz == 0 or hz == d - 1
    table.insert(out, {0, "zomboid:tiles", 0})
    table.insert(out, {4, "zomboid:roof", 0})
    if edge_x or edge_z then
        table.insert(out, {5, p.wall, 0})
    end
    if edge_x and edge_z then
        for dy = 1, 3 do table.insert(out, {dy, p.wall, 0}) end
        return
    end
    if edge_x or edge_z then
        if hz == 0 and hx == p.door then
            table.insert(out, {1, "base:wooden_door", 0})
            table.insert(out, {3, p.wall, 0})
            return
        end
        if hz == d - 1 and hx == 2 then
            table.insert(out, {1, "base:wooden_door", 0})
            table.insert(out, {3, p.wall, 0})
            return
        end
        local glass = (hz == 0 and math.abs(hx - p.door) > 1 and hx > 1 and hx < w - 2)
            or (edge_x and hz % 4 == 2)
        local mat = glass and "zomboid:window" or p.wall
        table.insert(out, {1, mat, 0})
        table.insert(out, {2, mat, 0})
        table.insert(out, {3, p.wall, 0})
        return
    end
    local container = STORE_CONTAINER[p.kind]
    local furniture, rot
    if (hz == 4 or hz == 7 or hz == 10) and hx >= 3 and hx <= w - 4 and hx ~= p.door then
        furniture, rot = container, (hz % 2 == 0) and 2 or 0
        if p.kind == "police" and hz == 10 then
            furniture = "zomboid:wardrobe"
        end
    elseif hz == 2 and hx >= 2 and hx <= 4 then
        furniture, rot = "zomboid:kitchen_cabinet", 0
    elseif hx == w - 2 and hz == d - 2 and p.kind ~= "police" then
        furniture, rot = "zomboid:fridge", 3
    end
    if furniture then
        table.insert(out, {1, furniture, rot})
        if furniture == "zomboid:crate" or furniture == "zomboid:medicine_cabinet" or furniture == "zomboid:kitchen_cabinet" then
            table.insert(out, {2, "core:struct_air", 0})
        end
    else
        table.insert(out, {1, "core:struct_air", 0})
        table.insert(out, {2, "core:struct_air", 0})
    end
    table.insert(out, {3, "core:struct_air", 0})
end

-- Returns surface kind of a column: road, line, sidewalk, path, building, lawn, park or nil (wild).
function town.column(wx, wz, out)
    if not town.in_town(wx, wz) then
        return nil
    end
    local cx, lx = cell_of(wx)
    local cz, lz = cell_of(wz)
    local road_x = lx < town.ROAD and cz >= -R and cz <= R and (cz < R or lz < town.ROAD)
    local road_z = lz < town.ROAD and cx >= -R and cx <= R and (cx < R or lx < town.ROAD)
    if road_x or road_z then
        if out then
            if road_x and not road_z and lx == 2 and wz % 6 < 3 then
                table.insert(out, {0, "zomboid:road_line", 0})
            elseif road_z and not road_x and lz == 2 and wx % 6 < 3 then
                table.insert(out, {0, "zomboid:road_line", 1})
            else
                table.insert(out, {0, "zomboid:asphalt", 0})
            end
            table.insert(out, {1, "core:struct_air", 0})
        end
        return "road"
    end
    if cx >= R or cz >= R then
        return nil
    end
    if lx <= 6 or lz <= 6 or lx >= 30 or lz >= 30 then
        if out then
            table.insert(out, {0, "zomboid:sidewalk", 0})
            table.insert(out, {1, "core:struct_air", 0})
        end
        return "sidewalk"
    end
    local p = town.plan(cx, cz)
    if p == nil then
        return "park"
    end
    local hx, hz = lx - p.x0, lz - p.z0
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        if out then
            if p.kind == "house" then
                house_column(p, hx, hz, out)
            else
                store_column(p, hx, hz, out)
            end
        end
        return "building"
    end
    if hx == p.door and hz < 0 then
        if out then
            table.insert(out, {0, "zomboid:sidewalk", 0})
            table.insert(out, {1, "core:struct_air", 0})
        end
        return "path"
    end
    return "lawn"
end

-- Kind of building at world position or nil.
function town.building_at(wx, wz)
    if not town.in_town(wx, wz) then
        return nil
    end
    local cx, lx = cell_of(wx)
    local cz, lz = cell_of(wz)
    local p = town.plan(cx, cz)
    if p == nil then
        return nil
    end
    local hx, hz = lx - p.x0, lz - p.z0
    if hx >= 0 and hx < p.w and hz >= 0 and hz < p.d then
        return p.kind
    end
    return nil
end

-- Tree placement chance for a column: returns tree index (0..2) or nil.
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
        local cx, lx = cell_of(wx)
        local cz, lz = cell_of(wz)
        if lx < 9 or lz < 9 or lx > 27 or lz > 27 then
            return nil
        end
        local p = town.plan(cx, cz)
        if p then
            local hx, hz = lx - p.x0, lz - p.z0
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

-- Interior points (world coords, feet level) of houses near the town center.
function town.house_interiors()
    local points = {}
    for cx = -R, R - 1 do
        for cz = -R, R - 1 do
            local p = town.plan(cx, cz)
            if p and p.kind == "house" then
                table.insert(points, {
                    cx * CELL + p.x0 + p.mid,
                    GROUND + 1,
                    cz * CELL + p.z0 + 2,
                    dist = math.abs(cx + 0.5) + math.abs(cz + 0.5)
                })
            end
        end
    end
    table.sort(points, function(a, b) return a.dist < b.dist end)
    return points
end

-- Player spawn position (entity center) inside the n-th closest house.
function town.spawn_point(index)
    local points = town.house_interiors()
    local p = points[math.max(1, math.min(index or 1, #points))]
    return {p[1] + 0.5, p[2] + 0.95, p[3] + 0.5}
end

return town
