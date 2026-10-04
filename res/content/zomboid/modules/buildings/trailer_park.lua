local rural = require "zomboid:buildings/_rural"

local put, room, surface = rural.put, rural.room, rural.surface

local park = {
    kind = "trailer_park",
    title = "трейлерный парк",
    color = {190, 190, 180},
    zones = {"rural"},
    weight = 2,
    cells = 2,
    loot = {
        wardrobe = {
            {"zomboid:tshirt", 3, 1, 1}, {"zomboid:jeans", 3, 1, 1}, {"zomboid:boots", 2, 1, 1},
            {"zomboid:cigarettes", 3, 1, 2}, {"zomboid:bat", 1, 1, 1}, {"zomboid:pistol", 0.4, 1, 1},
            {"zomboid:ammo_9mm", 0.8, 3, 8}, {"zomboid:magazine", 2, 1, 1},
        },
    },
}

local LANE = {20, 23}
local TW, TD = 12, 5
local ROWS = {3, 12, 21, 30}
local SIDES = {6, 26}

function park.plan(p, hash)
    p.w, p.d = 44, 40
    p.door = 21
    p.trailers = {}
    for si, sx in ipairs(SIDES) do
        for ri, rz in ipairs(ROWS) do
            if hash(si * 10 + ri) < 0.8 then
                table.insert(p.trailers, {sx, rz, si == 1})
            end
        end
    end
    p.car = {LANE[2] + 2, 26}
end

-- a mobile home 12×5 with its door at the end facing the lane
local function trailer(out, x, z, toward_lane_east)
    local door_x = toward_lane_east and TW - 1 or 0
    room(out, x, z, TW, TD, {wall = "zomboid:nature_trailer_siding", roof = "zomboid:nature_metal_roof",
        floor = "zomboid:carpet", door = {door_x, 2}})
    if x == 0 or z == 0 or x == TW - 1 or z == TD - 1 then
        return
    end
    local far = toward_lane_east and x or TW - 1 - x
    if far == 1 and z == 1 then
        put(out, 1, "zomboid:bed", 0)
    elseif far == 1 and z == 3 then
        put(out, 1, "zomboid:wardrobe", 2)
    elseif far == 3 and z == 3 then
        put(out, 1, "zomboid:tv", 2)
    elseif far == 5 and z == 1 then
        put(out, 1, "zomboid:couch", 0)
    elseif far == 8 and z == 3 then
        put(out, 1, "zomboid:fridge", 2)
    elseif far == 7 and z == 3 then
        put(out, 1, "zomboid:stove", 2)
    elseif far == 6 and z == 3 then
        put(out, 1, "zomboid:kitchen_cabinet", 2)
    elseif far == 7 and z == 1 then
        put(out, 1, "zomboid:sink", 0)
    end
end

function park.column(p, x, z, out)
    if x == p.car[1] and z == p.car[2] then
        surface(out, "zomboid:nature_dirt_path")
        put(out, 1, "zomboid:car_spawner")
        return
    end
    if x >= LANE[1] and x <= LANE[2] then
        surface(out, "zomboid:nature_dirt_path")
        return
    end
    for _, t in ipairs(p.trailers) do
        local tx, tz = x - t[1], z - t[2]
        if tx >= 0 and tx < TW and tz >= 0 and tz < TD then
            trailer(out, tx, tz, t[3])
            return
        end
        local door_x = t[3] and t[1] + TW or t[1] - 1
        if z == t[2] + 2 and (t[3] and x >= door_x and x < LANE[1] or not t[3] and x <= door_x and x > LANE[2]) then
            surface(out, "zomboid:nature_dirt_path")
            return
        end
    end
end

return park
