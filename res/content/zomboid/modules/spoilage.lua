local sandbox = require "zomboid:sandbox"
local clock = require "zomboid:clock"

local spoilage = {FRIDGE_RATE = 0.2}

local function power_off_hour()
    return (sandbox.get("power_shutoff_day") - 1) * 24
end

local function cold_hours(cold)
    return math.max(0, math.min(clock.hours, power_off_hour()) - cold)
end

function spoilage.age(invid, slot)
    local born = inventory.get_data(invid, slot, "born")
    if born == nil then
        return 0
    end
    local cold = inventory.get_data(invid, slot, "cold")
    return clock.hours - born - (cold and cold_hours(cold) * (1 - spoilage.FRIDGE_RATE) or 0)
end

function spoilage.ratio(invid, slot)
    local itemid = inventory.get(invid, slot)
    local days = itemid ~= 0 and item.properties[itemid]["zomboid:spoil-days"]
    return days and spoilage.age(invid, slot) / 24 / days or 0
end

-- Ages perishable food in the inventory; cold marks the inventory as a fridge, generator - powered by one now
function spoilage.check(invid, cold, generator)
    local rotten = item.index("zomboid:rotten_food")
    for slot = 0, inventory.size(invid) - 1 do
        local itemid, count = inventory.get(invid, slot)
        local days = itemid ~= 0 and item.properties[itemid]["zomboid:spoil-days"]
        if days then
            if inventory.get_data(invid, slot, "born") == nil then
                inventory.set_data(invid, slot, "born", clock.hours)
            end
            local chilled = inventory.get_data(invid, slot, "cold")
            if generator and chilled ~= nil then
                local cooled = clock.hours - math.max(chilled, power_off_hour())
                local age = spoilage.age(invid, slot) - math.max(0, cooled) * (1 - spoilage.FRIDGE_RATE)
                inventory.set_data(invid, slot, "born", clock.hours - age)
                inventory.set_data(invid, slot, "cold", clock.hours)
            elseif cold and chilled == nil then
                inventory.set_data(invid, slot, "cold", clock.hours)
            elseif not cold and chilled ~= nil then
                inventory.set_data(invid, slot, "born", clock.hours - spoilage.age(invid, slot))
                inventory.set_data(invid, slot, "cold", nil)
            end
            local ratio = spoilage.age(invid, slot) / 24 / days
            if ratio > 1.5 then
                inventory.set(invid, slot, rotten, count)
            elseif ratio > 1.0 then
                local stale = item.properties[itemid]["zomboid:stale"]
                if stale then
                    inventory.set(invid, slot, item.index(stale), count, inventory.get_all_data(invid, slot))
                end
                inventory.set_description(invid, slot, "Несвежее. Может вызвать отравление")
            elseif ratio > 0.6 then
                inventory.set_description(invid, slot, "Скоро испортится")
            else
                inventory.set_description(invid, slot, cold and "Свежее, в холодильнике" or "Свежее")
            end
        end
    end
end

return spoilage
