local mapping = require "zomboid:mapping"

local LEGEND = {
    {"house", "дома"}, {"grocery", "продукты"}, {"hardware", "хозтовары"}, {"pharmacy", "аптека"},
    {"police", "полиция"}, {"gas_station", "заправка"},
}

local function hex(c)
    return string.format("#%02x%02x%02x", c[1], c[2], c[3])
end

function on_open()
    mapping.draw(document.map.data, hud.get_player(), 2)
    local parts = {}
    for _, e in ipairs(LEGEND) do
        table.insert(parts, "[" .. hex(mapping.COLORS[e[1]]) .. "]" .. e[2])
    end
    document.legend.text = table.concat(parts, "  ")
end
