local crafting = require "zomboid:crafting"

local function refresh()
    local pid = hud.get_player()
    local invid = player.get_inventory(pid)
    local list = document.recipes
    list:clear()
    for i, recipe in ipairs(crafting.RECIPES) do
        local ok = crafting.can_craft(invid, recipe, pid)
        list:add(string.format(
            "<button onclick='craft(%d)' enabled='%s' padding='4' text-align='left' size='404,26'>%s</button>",
            i, tostring(ok), recipe.title))
        list:add(string.format(
            "<label color='%s' multiline='true' text-wrap='true' size='404,38' margin='4,0,0,6'>%s</label>",
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
