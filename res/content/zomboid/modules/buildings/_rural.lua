local rural = {}

local function put(out, dy, name, rot)
    table.insert(out, {dy, name, rot or 0})
end
rural.put = put

-- one-room box w×d at local x, z: floor, walls with windows, door {x, z} on the perimeter, roof at o.height
function rural.room(out, x, z, w, d, o)
    if x < 0 or z < 0 or x >= w or z >= d then
        return false
    end
    local height = o.height or 4
    local wall = o.wall
    local edge_x, edge_z = x == 0 or x == w - 1, z == 0 or z == d - 1
    put(out, 0, o.floor or "base:planks")
    put(out, height, o.roof or "zomboid:roof")
    if edge_x and edge_z then
        for dy = 1, height - 1 do put(out, dy, o.corner or wall) end
    elseif edge_x or edge_z then
        if o.door and x == o.door[1] and z == o.door[2] then
            put(out, 1, "base:wooden_door", edge_z and 0 or 1)
            for dy = 3, height - 1 do put(out, dy, wall) end
        else
            local along = edge_z and x or z
            local near_door = o.door and math.abs(x - o.door[1]) + math.abs(z - o.door[2]) <= 1
            local window = o.windows ~= false and along % 3 == 1 and not near_door
            for dy = 1, height - 1 do
                put(out, dy, (window and dy == 2) and "zomboid:window" or wall)
            end
        end
    else
        for dy = 1, height - 1 do put(out, dy, "core:struct_air") end
        if o.lamp ~= false and x == math.floor(w / 2) and z == math.floor(d / 2) then
            put(out, height - 1, "zomboid:lamp")
        end
    end
    return true
end

function rural.surface(out, name)
    put(out, 0, name)
    put(out, 1, "core:struct_air")
end

return rural
