local town = require "zomboid:town"

local GROUND = town.GROUND
local TREES = {"tree0", "tree1", "tree2"}
local ids = {}

local function id_of(name)
    local id = ids[name]
    if id == nil then
        id = block.index(name)
        ids[name] = id
    end
    return id
end

function generate_heightmap(x, y, w, h, bpd)
    local cx = (x + w * 0.5) * bpd
    local cz = (y + h * 0.5) * bpd
    local amp = math.min(1.0, math.max(0.0, (town.flat_dist(cx, cz) - 28) / 112.0))

    local map = Heightmap(w, h)
    if amp > 0.0 then
        map.noiseSeed = SEED
        map:noise({x, y}, 0.04 * bpd, 3, 1.0)
        map:mul(amp * 7.0 / 256.0)
    end
    map:add((GROUND + 0.5) / 256.0)
    return map
end

function place_structures(x, z, w, d, hmap, chunk_height)
    local placements = {}
    local column = {}
    for lz = 0, d - 1 do
        for lx = 0, w - 1 do
            local wx, wz = x + lx, z + lz
            for i = #column, 1, -1 do column[i] = nil end
            local kind = town.column(wx, wz, column)
            for _, entry in ipairs(column) do
                table.insert(placements, {
                    ":block", id_of(entry[2]), {wx, GROUND + entry[1], wz}, entry[3], 2
                })
            end
            local tree = town.tree_at(wx, wz, SEED % 100003)
            if tree then
                local height = math.floor(hmap:at(lx, lz) * chunk_height)
                if kind ~= nil then
                    height = GROUND
                end
                if height > town.SEA_LEVEL then
                    table.insert(placements, {
                        TREES[tree + 1], {lx - 2, height, lz - 2}, math.floor(town.hash(wx, wz, 9) * 4), 1
                    })
                end
            end
        end
    end
    return placements
end
