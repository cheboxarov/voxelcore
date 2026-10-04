local skills = require "zomboid:skills"

function on_use(pid)
    return skills.toggle_reading(pid)
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return skills.toggle_reading(pid)
end
