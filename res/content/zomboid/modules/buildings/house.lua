local SIDINGS = {"siding_white", "siding_blue", "siding_yellow", "siding_green", "siding_red"}

local house = {
    kind = "house",
    title = "дома",
    color = {170, 120, 80},
    zones = {"downtown", "suburb", "outskirts", "highway", "village"},
    weight = {downtown = 6, suburb = 62, outskirts = 40, highway = 1, village = 10},
    cells = 1,
}

function house.plan(p, hash)
    p.w = 9 + 2 * math.floor(hash(1) * 3)
    p.d = 9 + 2 * math.floor(hash(2) * 3)
    p.wall = "zomboid:" .. SIDINGS[1 + math.floor(hash(3) * #SIDINGS)]
    p.mid = math.floor(p.w / 2)
    p.split = math.floor(p.d / 2)
    p.door = p.mid
    if hash(23) < 0.4 then
        p.car = {-3, -2}
    end
end

function house.column(p, hx, hz, out)
    local w, d = p.w, p.d
    local wall = p.wall
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
    elseif hx == 1 and hz == 1 then
        furniture, rot = "zomboid:tv", 1
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
    local back_z = math.floor((p.split + d - 1) / 2)
    local lamp = (hx == p.mid and hz == math.floor(p.split / 2))
        or (hz == back_z and (hx == math.floor(p.mid / 2) or hx == p.mid + math.floor((w - 1 - p.mid) / 2)))
    table.insert(out, {3, lamp and "zomboid:lamp" or "core:struct_air", 0})
end

return house
