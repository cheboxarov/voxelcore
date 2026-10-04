local radio = require "zomboid:radio"

function on_use(pid)
    if radio.toggle(pid) then
        radio.listen(pid)
    end
    return true
end

function on_use_on_block(x, y, z, pid)
    local id = block.get(x, y, z)
    if block.has_tag(id, "zomboid:interactive") or block.name(id) == "base:wooden_door" then
        return false
    end
    return on_use(pid)
end
