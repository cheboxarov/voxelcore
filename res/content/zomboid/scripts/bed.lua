local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"

function on_interact(x, y, z, pid)
    if zombies.nearest_distance({x, y, z}) < 16 then
        survival.notify(pid, "Нельзя спать, когда рядом зомби!", "#ff7060")
        return true
    end
    survival.sleep(pid)
    return true
end
