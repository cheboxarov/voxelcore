-- Block textures: every face texture exists, aabb faces keep square pixels, palisade top is solid, furniture backs are plain
app.config_packs({"zomboid"})
app.new_world("zfaces", "1", "zomboid:town")

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local function image(name)
    for _, pack in ipairs({"zomboid", "base", "res"}) do
        local path = pack .. ":textures/blocks/" .. name:gsub("^blocks:", "") .. ".png"
        if file.exists(path) then
            return Canvas.decode(file.read_bytes(path), "png")
        end
    end
    check(false, "texture " .. name)
end

-- buildings.py, decor.py and nature.py textures are checked by their own owners
local FOREIGN = {bld = true, decor = true, nature = true}
local blocks, faces = 0, 0
for id = 0, block.defs_count() - 1 do
    local name = block.name(id)
    if name:find("^zomboid:") and block.get_model(id) ~= "none" then
        blocks = blocks + 1
        local tex = block.get_textures(id)
        for _, t in ipairs(tex) do image(t) end
        if block.get_model(id) == "aabb" and not FOREIGN[name:match("^zomboid:(%a+)_")] then
            local size = block.get_hitbox(id, 0)[2]
            local sx, sy, sz = size[1], size[2], size[3]
            local dims = {{sz, sy}, {sz, sy}, {sx, sz}, {sx, sz}, {sx, sy}, {sx, sy}}
            for i, d in ipairs(dims) do
                if d[1] >= 0.3 and d[2] >= 0.3 then
                    local img = image(tex[i])
                    local k = (img.width / img.height) / (d[1] / d[2])
                    check(math.abs(k - 1) < 0.12, string.format("%s face %d (%s) stretched x%.2f", name, i - 1, tex[i], k))
                    faces = faces + 1
                end
            end
        end
    end
end
log("blocks", blocks, "aabb faces with square pixels", faces)

local top = image("palisade_top")
for y = 0, top.height - 1 do
    for x = 0, top.width - 1 do
        check(math.floor(top:at(x, y) / 2 ^ 24) % 256 == 255, "palisade top is solid at " .. x .. "," .. y)
    end
end

for _, n in ipairs({"fridge", "stove", "sink", "kitchen_cabinet", "wardrobe"}) do
    local tex = block.get_textures(block.index("zomboid:" .. n))
    check(tex[5] ~= tex[6], n .. " back face differs from the front: " .. tex[5])
end
log("palisade top solid, furniture backs plain")
