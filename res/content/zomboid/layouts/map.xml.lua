local mapping = require "zomboid:mapping"
local town = require "zomboid:town"

local function hex(c)
    return string.format("#%02x%02x%02x", c[1], c[2], c[3])
end

function on_open()
    mapping.draw(document.map.data, hud.get_player())
    local parts = {}
    for _, def in ipairs(town.building_defs()) do
        table.insert(parts, "[" .. hex(def.color) .. "]" .. def.title)
    end
    document.legend.text = table.concat(parts, "  ")
end
