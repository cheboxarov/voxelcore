local SIDINGS = {"siding_white", "siding_blue", "siding_yellow", "siding_green", "siding_red"}
local ROOFS = {
    {"zomboid:roof", "zomboid:decor_roof_slab"},
    {"zomboid:decor_roof_grey", "zomboid:decor_roof_slab_grey"},
    {"zomboid:decor_roof_green", "zomboid:decor_roof_slab_green"},
}
local AIR = "core:struct_air"
local INNER = "zomboid:siding_white"
local GARAGE = 5

local house = {
    kind = "house",
    title = "дома",
    color = {170, 120, 80},
    zones = {"downtown", "suburb", "outskirts", "highway", "village"},
    weight = {downtown = 6, suburb = 62, outskirts = 40, highway = 1, village = 10},
    cells = 1,
    own_car = true,
}

function house.plan(p, hash)
    p.hw = 9 + 2 * math.floor(hash(1) * 3)
    p.d = 9 + 2 * math.floor(hash(2) * 3)
    p.wall = "zomboid:" .. SIDINGS[1 + math.floor(hash(3) * #SIDINGS)]
    p.mid = math.floor(p.hw / 2)
    p.split = math.floor(p.d / 2)
    p.door = p.mid
    local town = require "zomboid:town"
    local x, z = town.cell_center(p.cx, p.cz)
    local classic = math.abs(x - town.CENTER[1]) + math.abs(z - town.CENTER[2]) <= 125
    p.classic = classic
    p.floors = (not classic and p.d >= 13 and hash(30) < 0.6) and 2 or 1
    p.roof = ROOFS[classic and 1 or 1 + math.floor(hash(31) * #ROOFS)]
    p.gable = not classic and hash(32) < 0.6
    p.garage = not classic and hash(33) < 0.35 and p.lot_w >= p.hw + GARAGE + 4
    p.basement = not classic and hash(34) < 0.3
    p.study = not classic and hash(37) < 0.35
    p.kids = not classic and hash(36) < 0.4
    p.w = p.hw + (p.garage and GARAGE or 0)
    if not classic then
        local r = hash(35)
        p.boarded = r < 0.15
        p.looted = r >= 0.15 and r < 0.4
    end
    if p.garage then
        p.car = {p.hw + 1, 3}
    elseif hash(23) < 0.4 then
        p.car = {-3, -2}
    end
end

local function add(out, dy, name, rot)
    table.insert(out, {dy, name, rot or 0})
end

local function room_air(out, from, to)
    for dy = from, to do add(out, dy, AIR) end
end

local function roof(p, hx, hz, out, top, w)
    local block, slab = p.roof[1], p.roof[2]
    add(out, top, block)
    local edge = hx == 0 or hx == w - 1 or hz == 0 or hz == p.d - 1
    if not p.gable then
        if edge then add(out, top + 1, "zomboid:trim") end
        return
    end
    local s = math.min(hz, p.d - 1 - hz) + 1
    local full = math.floor(s / 2)
    local gable_end = hx == 0 or hx == w - 1
    for k = 1, full do
        add(out, top + k, (gable_end and (k < full or s % 2 == 1)) and p.wall or block)
    end
    if s % 2 == 1 then
        add(out, top + full + 1, slab)
    end
end

local function perimeter(p, hx, hz, out, base, w, ground)
    local d, wall = p.d, p.wall
    local edge_x, edge_z = hx == 0 or hx == w - 1, hz == 0 or hz == d - 1
    if edge_x and edge_z then
        for dy = 1, 3 do add(out, base + dy, "zomboid:trim") end
        return
    end
    if ground and ((hz == 0 and hx == p.door) or (hz == d - 1 and hx == 1)) then
        add(out, base + 1, "base:wooden_door")
        add(out, base + 3, wall)
        return
    end
    if ground and p.garage and hx == w - 1 and hz == p.split - 1 then
        room_air(out, base + 1, base + 2)
        add(out, base + 3, wall)
        return
    end
    local along = edge_z and hx or hz
    local near_door = ground and edge_z
        and (math.abs(hx - p.door) <= 1 and hz == 0 or math.abs(hx - 1) <= 1 and hz == d - 1)
    local mat = (along % 3 == 1 and not near_door) and "zomboid:window" or wall
    add(out, base + 1, mat)
    add(out, base + 2, mat)
    add(out, base + 3, wall)
end

local function furnish(out, dy, furniture, rot)
    add(out, dy, furniture, rot)
    if furniture ~= "zomboid:fridge" and furniture ~= "zomboid:wardrobe" and furniture ~= "zomboid:decor_bookshelf" then
        add(out, dy + 1, AIR)
    end
end

local function ground(p, hx, hz, out)
    local w, d = p.hw, p.d
    local up = p.floors == 2 and hx == 1 and hz >= 2 and hz <= 5
    local down = p.basement and hx == w - 2 and hz >= 1 and hz <= 4
    local floor = "base:planks"
    if hz > p.split and hx > 0 and hx < w - 1 and hz < d - 1 then
        if hx < p.mid then floor = "zomboid:tiles" elseif hx > p.mid then floor = "zomboid:carpet" end
    end
    if down then
        add(out, 1 - hz, "zomboid:decor_stairs", 2)
        if hz > 1 then add(out, 0, AIR) end
    else
        add(out, 0, floor)
    end
    if hx == 0 or hx == w - 1 or hz == 0 or hz == d - 1 then
        return perimeter(p, hx, hz, out, 0, w, true)
    end
    if hz == p.split then
        if hx == 2 or hx == w - 3 then
            room_air(out, 1, 2)
        else
            add(out, 1, INNER)
            add(out, 2, INNER)
        end
        add(out, 3, INNER)
        return
    end
    if hx == p.mid and hz > p.split then
        for dy = 1, 3 do add(out, dy, INNER) end
        return
    end
    if up then
        add(out, hz - 1, "zomboid:decor_stairs", 0)
        for dy = 1, 3 do
            if dy ~= hz - 1 then add(out, dy, AIR) end
        end
        return
    end
    local furniture, rot
    if hz == d - 2 and hx < p.mid and hx >= 2 then
        if hx == p.mid - 1 then furniture = "zomboid:fridge"
        elseif hx == 2 then furniture = "zomboid:sink"
        elseif hx == 3 then furniture = "zomboid:stove"
        else furniture = "zomboid:kitchen_cabinet" end
        rot = 2
    elseif hz == d - 2 and hx == w - 2 then
        furniture, rot = "zomboid:bed", 2
    elseif hz == d - 2 and hx == w - 3 then
        furniture, rot = p.kids and "zomboid:decor_toybox" or "zomboid:bed", 2
    elseif hz == d - 2 and hx == p.mid + 1 then
        furniture, rot = "zomboid:wardrobe", 2
    elseif hx == w - 2 and hz == p.split + 1 then
        furniture, rot = "zomboid:medicine_cabinet", 3
    elseif hx == w - 2 and hz == p.split + 2 and hz < d - 2 then
        furniture, rot = "zomboid:decor_toilet", 1
    elseif p.basement and hx == w - 3 and hz >= 2 and hz <= 4 then
        furniture, rot = "zomboid:decor_fence", 1
    elseif hx == w - 2 and (hz == 2 or hz == 3) and not p.basement then
        furniture, rot = "zomboid:couch", 3
    elseif hx == 1 and hz == 2 then
        furniture, rot = p.study and "zomboid:decor_desk" or "zomboid:crate", p.study and 3 or 1
    elseif hx == 1 and hz == p.split - 1 then
        furniture, rot = p.study and "zomboid:decor_bookshelf" or "zomboid:wardrobe", p.study and 3 or 1
    elseif hz == 1 and hx == (p.floors == 2 and 2 or 1) then
        furniture, rot = "zomboid:tv", p.floors == 2 and 2 or 1
    end
    if furniture and not down then
        furnish(out, 1, furniture, rot)
    else
        room_air(out, 1, 2)
    end
    local back_z = math.floor((p.split + d - 1) / 2)
    local lamp = (hx == p.mid and hz == math.floor(p.split / 2))
        or (hz == back_z and (hx == math.floor(p.mid / 2) or hx == p.mid + math.floor((w - 1 - p.mid) / 2)))
    add(out, 3, lamp and "zomboid:lamp" or AIR)
end

local function upstairs(p, hx, hz, out)
    local w, d = p.hw, p.d
    local stairwell = hx == 1 and hz >= 2 and hz <= 4
    if stairwell then
        add(out, 4, AIR)
    elseif not (hx == 1 and hz == 5) then
        local floor = "base:planks"
        if hz > p.split and hx > 0 and hx < w - 1 and hz < d - 1 then
            floor = hx < p.mid and "zomboid:tiles" or "zomboid:carpet"
        end
        add(out, 4, floor)
    end
    if hx == 0 or hx == w - 1 or hz == 0 or hz == d - 1 then
        return perimeter(p, hx, hz, out, 4, w, false)
    end
    local wall = (hz == p.split and hx ~= 2 and hx ~= w - 3)
        or (hx == p.mid and hz ~= p.split and hz ~= p.split - 2)
    if wall then
        for dy = 5, 7 do add(out, dy, INNER) end
        return
    end
    if hz == p.split or (hx == p.mid and hz == p.split - 2) then
        room_air(out, 5, 6)
        add(out, 7, INNER)
        return
    end
    local furniture, rot
    if (hx == 2 and (hz == 3 or hz == 4)) then
        furniture, rot = "zomboid:decor_fence", 1
    elseif hx == 1 and hz == 2 then
        furniture, rot = "zomboid:decor_fence", 0
    elseif hx == p.mid - 1 and hz == 1 then
        furniture, rot = "zomboid:decor_bookshelf", 2
    elseif hx == w - 2 and hz == 2 then
        furniture, rot = "zomboid:decor_desk", 1
    elseif hx == w - 2 and hz == p.split - 1 then
        furniture, rot = "zomboid:decor_bookshelf", 1
    elseif hx == 1 and hz == d - 3 then
        furniture, rot = "zomboid:decor_bathtub", 0
    elseif hx == 1 and hz == p.split + 1 then
        furniture, rot = "zomboid:medicine_cabinet", 3
    elseif hx == p.mid - 1 and hz == d - 2 then
        furniture, rot = "zomboid:decor_toilet", 0
    elseif hx == p.mid - 1 and hz == p.split + 1 then
        furniture, rot = "zomboid:sink", 0
    elseif hx == w - 2 and hz == d - 2 then
        furniture, rot = "zomboid:bed", 2
    elseif hx == w - 3 and hz == d - 2 then
        furniture, rot = "zomboid:decor_toybox", 2
    elseif hx == p.mid + 1 and hz == d - 2 then
        furniture, rot = "zomboid:wardrobe", 2
    end
    if hx == 1 and hz == d - 2 then
        add(out, 6, AIR)
    elseif hx == 1 and hz == 5 then
        room_air(out, 5, 6)
    elseif furniture then
        furnish(out, 5, furniture, rot)
    else
        room_air(out, 5, 6)
    end
    local front_z, back_z = math.floor(p.split / 2), math.floor((p.split + d - 1) / 2)
    local lamp = (hz == front_z or hz == back_z) and (hx == math.floor(p.mid / 2) or hx == p.mid + math.floor((w - 1 - p.mid) / 2))
    add(out, 7, lamp and not stairwell and "zomboid:lamp" or AIR)
end

local function basement(p, hx, hz, out)
    local w, d = p.hw, p.d
    add(out, -4, "zomboid:decor_concrete")
    if hx == 0 or hx == w - 1 or hz == 0 or hz == d - 1 then
        for dy = -3, -1 do add(out, dy, "zomboid:decor_concrete") end
        return
    end
    if hx == w - 2 and hz <= 4 then
        if hz > 1 then room_air(out, 2 - hz, -1) end
        return
    end
    local furniture, rot
    if hz == d - 2 and hx >= 2 and hx <= w - 3 and hx % 2 == 0 then
        furniture, rot = "zomboid:shelf", 2
    elseif hx == 1 and hz >= 2 and hz <= d - 3 and hz % 3 == 2 then
        furniture, rot = "zomboid:crate", 1
    elseif hx == w - 2 and hz == d - 2 then
        furniture, rot = "zomboid:decor_workbench", 3
    end
    if furniture then
        add(out, -3, furniture, rot)
        if furniture ~= "zomboid:shelf" then add(out, -2, AIR) end
    else
        room_air(out, -3, -2)
    end
    local lamp = hx % 4 == 2 and hz % 4 == 2
    add(out, -1, lamp and "zomboid:lamp" or AIR)
end

local function garage(p, gx, hz, out)
    local d = p.d
    add(out, 0, "zomboid:decor_concrete")
    add(out, 4, p.roof[1])
    local right, front, back = gx == GARAGE - 1, hz == 0, hz == d - 1
    if right or front or back then
        add(out, 5, "zomboid:trim")
    end
    if right and (front or back) then
        for dy = 1, 3 do add(out, dy, "zomboid:trim") end
        return
    end
    if front and gx <= 2 then
        room_air(out, 1, 2)
        add(out, 3, p.wall)
        return
    end
    if right or front or back then
        local mat = (right and hz % 4 == 2) and "zomboid:window" or p.wall
        add(out, 1, mat)
        add(out, 2, mat)
        add(out, 3, p.wall)
        return
    end
    if p.car and gx == p.car[1] - p.hw and hz == p.car[2] then
        add(out, 1, "zomboid:car_spawner")
        add(out, 2, AIR)
    elseif hz == d - 2 and gx >= 2 then
        furnish(out, 1, "zomboid:decor_workbench", 2)
    elseif hz == d - 3 and gx == 3 then
        furnish(out, 1, "zomboid:crate", 1)
    elseif hz == d - 2 and gx == 0 then
        furnish(out, 1, "zomboid:crate", 2)
    else
        room_air(out, 1, 2)
    end
    add(out, 3, (gx == 2 and hz == math.floor(d / 2)) and "zomboid:lamp" or AIR)
end

local function damage(p, hx, hz, out, first)
    local edge = hx == 0 or hx == p.hw - 1 or hz == 0 or hz == p.d - 1
    local back_door = hz == p.d - 1 and hx == 1
    local h = (hx * 7 + hz * 13) % 10
    local note = hx == p.mid + 1 and hz == p.split - 1
    local hole = p.basement and hx == p.hw - 2 and hz <= 4
    for i = first, #out do
        local e = out[i]
        if e[1] == 1 or e[1] == 2 then
            if p.boarded and e[2] == "zomboid:window" then
                e[2] = "zomboid:barricade"
            elseif p.boarded and back_door and e[2] == "base:wooden_door" then
                e[2] = "zomboid:door_barricade"
            elseif p.looted and back_door and e[2] == "base:wooden_door" then
                e[2] = AIR
            elseif p.looted and e[2] == "zomboid:window" and h < 5 then
                e[2] = "zomboid:window_broken"
            elseif not edge and not hole and e[1] == 1 and e[2] == AIR and hz ~= 2 then
                if note then
                    e[2] = "zomboid:decor_note"
                elseif h == 0 then
                    e[2], e[3] = "zomboid:decor_blood", (hx + hz) % 4
                elseif h == 9 and p.looted then
                    e[2], e[3] = "zomboid:decor_litter", hz % 4
                end
            end
        end
    end
end

function house.column(p, hx, hz, out)
    if p.hw == nil then
        p.hw, p.floors, p.roof = p.w, 1, ROOFS[1]
    end
    if hx >= p.hw then
        return garage(p, hx - p.hw, hz, out)
    end
    local first = #out + 1
    ground(p, hx, hz, out)
    if p.boarded or p.looted then
        damage(p, hx, hz, out, first)
    end
    if p.floors == 2 then
        upstairs(p, hx, hz, out)
    end
    if p.basement then
        basement(p, hx, hz, out)
    end
    roof(p, hx, hz, out, 4 * p.floors, p.hw)
end

function house.lot(p, hx, hz, out)
    if not p.garage or hz >= 0 or hz < -p.oz or hx < p.hw or hx > p.hw + 2 then
        return nil
    end
    if out then
        table.insert(out, {0, "zomboid:asphalt", 0})
        table.insert(out, {1, AIR, 0})
    end
    return "path"
end

return house
