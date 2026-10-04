local radio = require "zomboid:radio"

function on_use(pid)
    if radio.toggle(pid) then
        radio.listen(pid)
    end
    return true
end
