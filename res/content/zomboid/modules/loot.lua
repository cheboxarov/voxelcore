local town = require "zomboid:town"
local cars = require "zomboid:cars"

local loot = {}

local TABLES = {
    fridge = {
        {"zomboid:bread", 4, 1, 2}, {"zomboid:apple", 4, 1, 3}, {"zomboid:water_bottle", 3, 1, 1},
        {"zomboid:soda", 4, 1, 2}, {"zomboid:chocolate", 2, 1, 1}, {"zomboid:canned_beans", 1, 1, 1},
        {"zomboid:raw_meat", 3, 1, 2}, {"zomboid:potato", 2, 1, 3}, {"zomboid:carrot", 2, 1, 3},
    },
    kitchen_cabinet = {
        {"zomboid:canned_beans", 5, 1, 2}, {"zomboid:chips", 3, 1, 2}, {"zomboid:empty_bottle", 3, 1, 2},
        {"zomboid:knife", 2, 1, 1}, {"zomboid:frying_pan", 2, 1, 1}, {"zomboid:matches", 2, 1, 1},
        {"zomboid:rag", 2, 1, 2}, {"zomboid:chocolate", 1, 1, 1}, {"zomboid:book_cooking_1", 1, 1, 1},
        {"zomboid:alarm_clock.item", 1, 1, 1},
        {"zomboid:cooking_pot", 2, 1, 1}, {"zomboid:potato", 2, 1, 2}, {"zomboid:cigarettes", 1, 1, 1},
        {"zomboid:seeds_carrot", 1, 1, 2}, {"zomboid:radio", 1, 1, 1}, {"zomboid:map", 1, 1, 1},
        {"zomboid:lore_note", 1, 1, 1},
    },
    stove = {
        {"zomboid:frying_pan", 3, 1, 1}, {"zomboid:canned_beans", 1, 1, 1}, {"zomboid:book_cooking_2", 1, 1, 1},
        {"zomboid:cooking_pot", 3, 1, 1},
    },
    wardrobe = {
        {"zomboid:rag", 6, 1, 3}, {"zomboid:bat", 1, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
        {"zomboid:bandage", 1, 1, 1}, {"zomboid:painkillers", 1, 1, 1}, {"zomboid:matches", 1, 1, 1},
        {"zomboid:book_melee_1", 1, 1, 1}, {"zomboid:book_sneaking_1", 1, 1, 1},
        {"zomboid:alarm_clock.item", 1, 1, 1},
        {"zomboid:tshirt", 3, 1, 1}, {"zomboid:sweater", 3, 1, 1}, {"zomboid:knit_hat", 3, 1, 1},
        {"zomboid:jeans", 3, 1, 1}, {"zomboid:leather_jacket", 1, 1, 1}, {"zomboid:raincoat", 2, 1, 1},
        {"zomboid:boots", 2, 1, 1}, {"zomboid:school_bag", 1, 1, 1}, {"zomboid:novel", 2, 1, 1},
        {"zomboid:magazine", 2, 1, 2}, {"zomboid:cigarettes", 1, 1, 1},
        {"zomboid:map", 1, 1, 1}, {"zomboid:radio", 1, 1, 1}, {"zomboid:lore_note", 1, 1, 1},
    },
    medicine_cabinet = {
        {"zomboid:bandage", 5, 1, 3}, {"zomboid:disinfectant", 3, 1, 1}, {"zomboid:painkillers", 3, 1, 1},
        {"zomboid:antibiotics", 1, 1, 1}, {"zomboid:rag", 2, 1, 2}, {"zomboid:book_first_aid_1", 1, 1, 1},
        {"zomboid:splint", 1, 1, 1},
    },
    crate = {
        {"zomboid:plank", 4, 2, 6}, {"zomboid:nails", 4, 5, 20}, {"zomboid:hammer", 2, 1, 1},
        {"zomboid:empty_bottle", 2, 1, 2}, {"zomboid:flashlight", 1, 1, 1}, {"zomboid:bat", 1, 1, 1},
        {"zomboid:crowbar", 1, 1, 1}, {"zomboid:book_carpentry_1", 1, 1, 1}, {"zomboid:stick", 2, 1, 3},
        {"zomboid:hiking_bag", 1, 1, 1},
        {"zomboid:seeds_potato", 1, 1, 2}, {"zomboid:shovel", 1, 1, 1}, {"zomboid:gas_can_empty", 1, 1, 1},
    },
    shelf = {
        {"zomboid:canned_beans", 5, 1, 3}, {"zomboid:chips", 4, 1, 3}, {"zomboid:chocolate", 3, 1, 2},
        {"zomboid:soda", 4, 1, 3}, {"zomboid:water_bottle", 4, 1, 2}, {"zomboid:bread", 2, 1, 2},
        {"zomboid:potato", 3, 1, 3}, {"zomboid:carrot", 3, 1, 3}, {"zomboid:cigarettes", 2, 1, 1},
        {"zomboid:magazine", 2, 1, 1},
    },
    locker = {
        {"zomboid:tshirt", 3, 1, 1}, {"zomboid:boots", 2, 1, 1}, {"zomboid:flashlight", 2, 1, 1},
        {"zomboid:rag", 3, 1, 2}, {"zomboid:cigarettes", 2, 1, 1}, {"zomboid:magazine", 2, 1, 1},
    },
    ammo_crate = {
        {"zomboid:ammo_9mm", 3, 4, 10}, {"zomboid:shotgun_shells", 2, 2, 6}, {"zomboid:canned_beans", 3, 1, 3},
        {"zomboid:water_bottle", 2, 1, 2}, {"zomboid:bandage", 2, 1, 2},
    },
    mailbox = {
        {"zomboid:magazine", 4, 1, 1}, {"zomboid:lore_note", 3, 1, 1}, {"zomboid:map", 1, 1, 1},
        {"zomboid:cigarettes", 1, 1, 1}, {"zomboid:seeds_carrot", 1, 1, 1},
    },
    trash = {
        {"zomboid:rotten_food", 5, 1, 2}, {"zomboid:empty_bottle", 4, 1, 1}, {"zomboid:dirty_rag", 3, 1, 1},
        {"zomboid:magazine", 2, 1, 1}, {"zomboid:chips", 1, 1, 1}, {"zomboid:lore_note", 1, 1, 1},
    },
    dumpster = {
        {"zomboid:rotten_food", 5, 1, 3}, {"zomboid:empty_bottle", 4, 1, 2}, {"zomboid:dirty_rag", 3, 1, 2},
        {"zomboid:plank", 3, 1, 2}, {"zomboid:stick", 2, 1, 2}, {"zomboid:nails", 1, 2, 6},
        {"zomboid:canned_beans", 1, 1, 1}, {"zomboid:magazine", 1, 1, 1}, {"zomboid:crowbar", 0.3, 1, 1},
    },
    army = {
        {"zomboid:canned_beans", 5, 2, 4}, {"zomboid:water_bottle", 4, 1, 3}, {"zomboid:bandage", 4, 1, 3},
        {"zomboid:ammo_9mm", 2, 4, 12}, {"zomboid:shotgun_shells", 1.5, 2, 6}, {"zomboid:flashlight", 2, 1, 1},
        {"zomboid:matches", 2, 1, 1}, {"zomboid:boots", 1, 1, 1}, {"zomboid:hiking_bag", 1, 1, 1},
        {"zomboid:disinfectant", 1, 1, 1}, {"zomboid:map", 1, 1, 1}, {"zomboid:pistol", 0.3, 1, 1},
    },
    workbench = {
        {"zomboid:nails", 5, 5, 20}, {"zomboid:hammer", 3, 1, 1}, {"zomboid:plank", 3, 2, 5},
        {"zomboid:axe", 1, 1, 1}, {"zomboid:crowbar", 1, 1, 1}, {"zomboid:shovel", 1, 1, 1},
        {"zomboid:gas_can_empty", 2, 1, 1}, {"zomboid:gas_can", 1, 1, 1}, {"zomboid:flashlight", 1, 1, 1},
        {"zomboid:book_carpentry_1", 1, 1, 1}, {"zomboid:rag", 2, 1, 2},
    },
    desk = {
        {"zomboid:lore_note", 4, 1, 1}, {"zomboid:magazine", 3, 1, 1}, {"zomboid:novel", 2, 1, 1},
        {"zomboid:map", 2, 1, 1}, {"zomboid:matches", 1, 1, 1}, {"zomboid:radio", 1, 1, 1},
        {"zomboid:book_first_aid_1", 1, 1, 1}, {"zomboid:book_cooking_1", 1, 1, 1}, {"zomboid:painkillers", 1, 1, 1},
    },
    bookshelf = {
        {"zomboid:novel", 5, 1, 2}, {"zomboid:magazine", 3, 1, 2}, {"zomboid:book_carpentry_1", 1, 1, 1},
        {"zomboid:book_cooking_1", 1, 1, 1}, {"zomboid:book_first_aid_1", 1, 1, 1}, {"zomboid:book_melee_1", 1, 1, 1},
        {"zomboid:book_sneaking_1", 1, 1, 1}, {"zomboid:book_cooking_2", 0.5, 1, 1}, {"zomboid:lore_note", 1, 1, 1},
    },
    toys = {
        {"zomboid:school_bag", 2, 1, 1}, {"zomboid:chocolate", 3, 1, 2}, {"zomboid:magazine", 2, 1, 1},
        {"zomboid:lore_note", 2, 1, 1}, {"zomboid:bat", 1, 1, 1}, {"zomboid:flashlight", 1, 1, 1},
        {"zomboid:knit_hat", 1, 1, 1},
    },
}

local ROLLS = {
    fridge = {1, 4}, kitchen_cabinet = {1, 3}, stove = {0, 1}, wardrobe = {1, 4}, medicine_cabinet = {1, 3},
    crate = {1, 4}, shelf = {2, 5}, mailbox = {0, 2}, trash = {0, 2}, dumpster = {1, 4}, army = {2, 5},
    workbench = {1, 4}, desk = {1, 3}, bookshelf = {1, 4}, toys = {1, 3},
}

local function choose(entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + e[2] end
    local r = math.random() * total
    for _, e in ipairs(entries) do
        r = r - e[2]
        if r <= 0 then
            return e
        end
    end
    return entries[#entries]
end

function loot.table_for(container, x, z)
    local _, p = town.building_at(x, z)
    local special = p and p.def.loot and p.def.loot[container]
    return special or TABLES[container]
end

function loot.rolls(container, entries)
    return entries.rolls or ROLLS[container] or {1, 3}
end

function loot.fill(invid, container, x, z, apocalypse_hour)
    local entries = loot.table_for(container, x, z)
    if entries == nil then
        return 0
    end
    local rolls = loot.rolls(container, entries)
    local n = math.random(rolls[1], rolls[2])
    local _, p = town.building_at(x, z)
    if p and p.looted then
        n = math.floor(n / 2)
    end
    local added = 0
    for _ = 1, n do
        local e = choose(entries)
        local itemid = item.index(e[1])
        local count = math.random(e[3], e[4])
        local props = item.properties[itemid]
        if props and props["zomboid:spoil-days"] then
            for _ = 1, count do
                local slot = inventory.find_by_item(invid, 0, 0, inventory.size(invid) - 1, 0)
                if slot then
                    inventory.set(invid, slot, itemid, 1)
                    inventory.set_data(invid, slot, "born", apocalypse_hour - math.random() * 12)
                    if container == "fridge" then
                        inventory.set_data(invid, slot, "cold", apocalypse_hour)
                    end
                    added = added + 1
                end
            end
        else
            local rest = inventory.add(invid, itemid, count)
            added = added + count - rest
        end
    end
    if cars.add_key(invid, container, x, z) then
        added = added + 1
    end
    return added
end

local ZOMBIE_DROPS = {
    {"zomboid:rag", 4, 1, 2}, {"zomboid:chips", 2, 1, 1}, {"zomboid:water_bottle", 1, 1, 1},
    {"zomboid:bandage", 1, 1, 1}, {"zomboid:matches", 1, 1, 1}, {"zomboid:chocolate", 1, 1, 1},
    {"zomboid:magazine", 1, 1, 1}, {"zomboid:cigarettes", 1, 1, 1},
}

function loot.zombie_drop()
    local e = choose(ZOMBIE_DROPS)
    return item.index(e[1]), math.random(e[3], e[4])
end

return loot
