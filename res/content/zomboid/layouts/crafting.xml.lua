local crafting = require "zomboid:crafting"

local function refresh()
    local pid = hud.get_player()
    local invid = player.get_inventory(pid)
    local list = document.recipes
    list:clear()
    for i, recipe in ipairs(crafting.RECIPES) do
        local ok = crafting.can_craft(invid, recipe)
        list:add(string.format(
            "<button onclick='craft(%d)' enabled='%s' padding='6' text-align='left' size='396,44'>%s</button>",
            i, tostring(ok), recipe.title))
        list:add(string.format(
            "<label color='%s' multiline='true' text-wrap='true' size='396,0' autoresize='true'>%s</label>",
            ok and "#c0e0c0" or "#909090", crafting.describe(recipe)))
    end
end

function craft(index)
    crafting.craft(hud.get_player(), index)
    refresh()
end

function on_open()
    refresh()
end
