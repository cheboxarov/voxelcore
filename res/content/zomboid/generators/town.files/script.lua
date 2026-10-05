local town = require "zomboid:town"
local nature = require "zomboid:nature"
local flora = require "zomboid:flora"

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
    return nature.heightmap(x, y, w, h, bpd, SEED)
end

function generate_biome_parameters(x, y, w, h, bpd)
    return nature.biome_params(x, y, w, h, bpd, SEED)
end

function place_structures(x, z, w, d, hmap, chunk_height)
    local placements = {}
    local column = {}
    local biomes = nature.chunk_biomes(x / w, z / d, SEED)
    for lz = 0, d - 1 do
        for lx = 0, w - 1 do
            local wx, wz = x + lx, z + lz
            for i = #column, 1, -1 do column[i] = nil end
            local kind = town.column(wx, wz, column)
            for _, entry in ipairs(column) do
                table.insert(placements, {
                    ":block", id_of(entry[2]), {wx, GROUND + entry[1], wz}, entry[3], entry[4] or 2
                })
            end
            if kind == nil then
                local h = math.floor(hmap:at(lx, lz) * chunk_height)
                flora.column(placements, wx, wz, lx, lz, h, biomes[lz * w + lx + 1], hmap, SEED % 100003)
            elseif kind == "park" or kind == "lawn" then
                local tree = town.tree_at(wx, wz, SEED % 100003)
                if tree then
                    table.insert(placements, {
                        TREES[tree + 1], {lx - 2, GROUND, lz - 2}, math.floor(town.hash(wx, wz, 9) * 4), 1
                    })
                end
            end
        end
    end
    return placements
end
