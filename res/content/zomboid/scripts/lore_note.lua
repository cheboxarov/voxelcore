local lore = require "zomboid:lore"
local inv = require "zomboid:inv"

local function read(pid)
    local _, _, invid, slot = inv.held(pid)
    local id = inventory.get_data(invid, slot, "story")
    if lore.STORIES[id] == nil then
        id = lore.home_story(math.random())
        inventory.set_data(invid, slot, "story", id)
        inventory.set_description(invid, slot, lore.STORIES[id].title)
    end
    lore.read(pid, id)
    return true
end

function on_use(pid)
    return read(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return read(pid)
end
