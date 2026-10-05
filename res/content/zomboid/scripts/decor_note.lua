local lore = require "zomboid:lore"
local survival = require "zomboid:survival"

function on_interact(x, y, z, pid)
    local id = lore.story_at(x, z)
    if lore.give(pid, id) then
        block.set(x, y, z, 0, 0)
        survival.notify(pid, "Вы подобрали записку: " .. lore.STORIES[id].title, "#e0d0a0")
    end
    lore.read(pid, id)
    return true
end
