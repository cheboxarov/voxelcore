local rural = require "zomboid:buildings/_rural"
local house = require "zomboid:buildings/house"

local put, room, surface = rural.put, rural.room, rural.surface

local farm = {
    kind = "farm",
    title = "фермы",
    color = {176, 150, 82},
    zones = {"rural"},
    weight = 5,
    cells = 2,
    loot = {
        crate = {
            {"zomboid:seeds_carrot", 5, 2, 6}, {"zomboid:seeds_potato", 5, 2, 6}, {"zomboid:shovel", 4, 1, 1},
            {"zomboid:axe", 2, 1, 1}, {"zomboid:hammer", 2, 1, 1}, {"zomboid:nails", 2, 5, 20},
            {"zomboid:plank", 3, 2, 6}, {"zomboid:gas_can", 2, 1, 1}, {"zomboid:gas_can_empty", 2, 1, 1},
            {"zomboid:potato", 3, 2, 5}, {"zomboid:carrot", 3, 2, 5}, {"zomboid:matches", 1, 1, 1},
        },
        wardrobe = {
            {"zomboid:jeans", 3, 1, 1}, {"zomboid:boots", 3, 1, 1}, {"zomboid:raincoat", 2, 1, 1},
            {"zomboid:sweater", 2, 1, 1}, {"zomboid:knit_hat", 2, 1, 1}, {"zomboid:shotgun", 0.7, 1, 1},
            {"zomboid:shotgun_shells", 1.5, 2, 6}, {"zomboid:flashlight", 1, 1, 1},
        },
    },
}

local HOUSE = {2, 2}
local BARN = {28, 3, 15, 13}
local SILO = {17, 7}
local FIELD = {1, 19, 44, 44}
local WALLS = {"zomboid:siding_white", "zomboid:siding_yellow", "zomboid:siding_red"}

function farm.plan(p, hash)
    p.w, p.d = 46, 46
    p.door = 24
    p.house = {w = 11, d = 9, mid = 5, split = 4, door = 5, wall = WALLS[1 + math.floor(hash(1) * #WALLS)]}
    p.crop_split = 12 + math.floor(hash(2) * 20)
    p.car = {p.door, 14}
end

local function barn(out, x, z)
    local w, d = BARN[3], BARN[4]
    put(out, 0, "base:dirt")
    put(out, 6, "zomboid:roof")
    local edge = x == 0 or z == 0 or x == w - 1 or z == d - 1
    if edge then
        local gate = z == 0 and x >= 5 and x <= 9
        for dy = 1, 5 do
            if gate and dy <= 4 then
                put(out, dy, "core:struct_air")
            else
                local window = not gate and z > 0 and z % 4 == 2 and (dy == 2 or dy == 3)
                put(out, dy, window and "zomboid:window" or "zomboid:nature_barn_wood")
            end
        end
        return
    end
    for dy = 1, 5 do put(out, dy, "core:struct_air") end
    if z >= d - 3 and (x <= 4 or x >= w - 5) then
        for dy = 1, (x + z) % 2 == 0 and 3 or 2 do put(out, dy, "zomboid:nature_hay") end
    elseif x == 1 and (z == 2 or z == 4) then
        put(out, 1, "zomboid:crate", 1)
    elseif x == w - 2 and z == 3 then
        put(out, 1, "zomboid:crate", 3)
    elseif x == 7 and z == 6 then
        put(out, 5, "zomboid:lamp")
    end
end

local function silo(out, x, z)
    local r2 = x * x + z * z
    put(out, 0, "base:stone")
    if r2 >= 5 then
        for dy = 1, 12 do put(out, dy, "zomboid:nature_silo") end
    else
        for dy = 1, 12 do put(out, dy, "core:struct_air") end
    end
    put(out, 13, "zomboid:nature_metal_roof")
    if r2 <= 2 then
        put(out, 14, "zomboid:nature_metal_roof")
    end
end

local function field(out, p, x, z)
    local x0, z0, x1, z1 = FIELD[1], FIELD[2], FIELD[3], FIELD[4]
    local edge_x, edge_z = x == x0 or x == x1, z == z0 or z == z1
    if edge_x or edge_z then
        if z == z0 and x == p.door then
            put(out, 1, "zomboid:wooden_gate", 0)
        elseif z == z0 and x == p.door + 1 then
            put(out, 1, "core:struct_air")
        else
            put(out, 1, "zomboid:nature_fence", edge_z and 0 or 1)
        end
        return
    end
    if (z - z0) % 3 == 0 or x == p.door or x == p.door + 1 then
        surface(out, "zomboid:nature_dirt_path")
        return
    end
    put(out, 0, "zomboid:garden_bed")
    put(out, 1, x < p.crop_split and "zomboid:crop_carrot" or "zomboid:crop_potato")
end

function farm.column(p, x, z, out)
    if x == p.car[1] and z == p.car[2] then
        put(out, 0, "zomboid:nature_dirt_path")
        put(out, 1, "zomboid:car_spawner")
        return
    end
    if x >= HOUSE[1] and x < HOUSE[1] + p.house.w and z >= HOUSE[2] and z < HOUSE[2] + p.house.d then
        house.column(p.house, x - HOUSE[1], z - HOUSE[2], out)
        return
    end
    if x >= BARN[1] and x < BARN[1] + BARN[3] and z >= BARN[2] and z < BARN[2] + BARN[4] then
        barn(out, x - BARN[1], z - BARN[2])
        return
    end
    local sx, sz = x - SILO[1], z - SILO[2]
    if sx * sx + sz * sz <= 10 then
        silo(out, sx, sz)
        return
    end
    if z >= FIELD[2] then
        if x >= FIELD[1] and x <= FIELD[3] and z <= FIELD[4] then
            field(out, p, x, z)
        end
        return
    end
    if (x >= p.door - 1 and x <= p.door + 1) or (z == 1 and x >= HOUSE[1] + p.house.door and x < p.door)
        or (z >= BARN[2] + BARN[4] and z <= 17 and x >= BARN[1] + 4 and x <= BARN[1] + 10) then
        surface(out, "zomboid:nature_dirt_path")
        return
    end
    if z == 0 or x == 0 or x == p.w - 1 then
        put(out, 1, "zomboid:nature_fence", z == 0 and 0 or 1)
        return
    end
    if x == BARN[1] - 1 and (z == 16 or z == 17) then
        put(out, 1, "zomboid:nature_hay")
    end
end

return farm
