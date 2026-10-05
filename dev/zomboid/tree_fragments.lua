-- Bakes spruce, birch and dead tree fragments for the town generator; run with --headless --test
app.config_packs({"zomboid"})
app.new_world("ztrees", "1", "zomboid:town")

local hash = require("zomboid:town").hash
local DIR = "zomboid:generators/town.files/fragments/"
local X, Y, Z = 8, 200, 8
local R, H = 3, 16

local pid = player.create("baker")
player.set_pos(pid, X, Y, Z)
app.sleep_until(function() return block.get(X + R, Y, Z + R) ~= -1 and block.get(X - R, Y, Z - R) ~= -1 end, 6000)

local function put(name, x, y, z, rot)
    block.set(X + x, Y + y, Z + z, block.index(name), block.compose_state({rot or 0, 0, 0}))
end

local function disc(name, y, r, skip_center, salt)
    local lim = r * r + r * 0.8
    for i = -r, r do
        for j = -r, r do
            local d = i * i + j * j
            if d <= lim and not (skip_center and i == 0 and j == 0) and (d < r * r or hash(i, j, y + salt) < 0.7) then
                put(name, i, y, j)
            end
        end
    end
end

local function spruce(h, salt)
    for y = 0, h - 1 do put("zomboid:nature_spruce_log", 0, y, 0) end
    for y = 2, h + 1 do
        local t = h + 1 - y
        local r = math.min(3, math.floor(t * 0.45))
        if t % 2 == 1 and r > 0 then r = r - 1 end
        disc("zomboid:nature_spruce_leaves", y, r, y < h, salt)
    end
end

local function birch(h, salt)
    for y = 0, h - 1 do put("zomboid:nature_birch_log", 0, y, 0) end
    for y = h - 3, h + 1 do
        local r = (y == h - 3 or y == h) and 1 or (y == h + 1 and 0 or 2)
        disc("zomboid:nature_birch_leaves", y, r, y < h, salt)
    end
end

local function dead(h)
    for y = 0, h - 1 do put("zomboid:nature_spruce_log", 0, y, 0) end
    put("zomboid:nature_log", 1, h - 2, 0, 0)
    put("zomboid:nature_log", 0, h - 1, 1, 1)
    if h > 5 then put("zomboid:nature_log", -1, h - 3, 0, 0) end
end

local function bake(name, build)
    for x = -R, R do
        for z = -R, R do
            for y = 0, H do block.set(X + x, Y + y, Z + z, 0, 0) end
        end
    end
    build()
    local fragment = generation.create_fragment({X - R, Y, Z - R}, {X + R, Y + H, Z + R}, false)
    generation.save_fragment(fragment, DIR .. name .. ".vox")
    print("baked " .. name)
end

for h = 7, 12 do bake("spruce" .. (h - 7), function() spruce(h, h * 7) end) end
for h = 6, 9 do bake("birch" .. (h - 6), function() birch(h, h * 5) end) end
for h = 4, 6 do bake("dead" .. (h - 4), function() dead(h) end) end

app.close_world(false)
app.delete_world("ztrees")
