local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local inv = require "zomboid:inv"

local radio = {
    SLOT_HOURS = 1.5,
    SILENCE_DAY = 6,
}

local BROADCASTS = {
    {
        "Экстренный выпуск: в округе вспышка неизвестной болезни. Заболевшие агрессивны и кусаются.",
        "Власти просят граждан оставаться дома, запереть двери и окна.",
        "Симптомы: жар, бледность, спутанность сознания. Не приближайтесь к больным.",
        "Укушенным немедленно обратиться в больницу. Повторяем: избегайте укусов.",
        "Совет спасателей: заколотите окна досками и гвоздями, держите при себе оружие.",
        "Пожарная служба напоминает: не оставляйте костры и плиты без присмотра.",
        "Ночью заражённые активнее. Не выходите из дома после заката.",
        "Магазины закрываются. Сделайте запасы воды и консервов.",
        "Транспорт на выезде из города остановлен военными. Оставайтесь на месте.",
        "Мэрия: эвакуационные пункты переполнены. Ждите дальнейших указаний.",
        "Совет: в хозяйственном магазине есть доски, гвозди и инструменты.",
        "Без связи с соседним округом. Новые сообщения о нападениях поступают каждый час.",
    },
    {
        "Карантинная зона расширена. Город окружён кордоном, выезд запрещён.",
        "Энергокомпания предупреждает: из-за нехватки персонала электричество может пропасть в ближайшие дни.",
        "Запаситесь бензином: генератор поможет, когда отключат свет. Он шумный - зомби услышат.",
        "Водоканал: подача воды может прекратиться. Наполните все ёмкости.",
        "Кипятите воду из озёр и рек перед питьём.",
        "Укус смертелен. Лекарства не существует. Повторяем: лекарства не существует.",
        "Мертвецы идут на шум: выстрелы, звон стекла, двигатели машин.",
        "Ходят слухи об орде, движущейся к городу с востока.",
        "Совет: огород и семена помогут пережить зиму. Дождевую воду можно собирать в бочки.",
        "Карты города остались на заправке и в домах - они помогут не заблудиться.",
    },
    {
        "Военные отступают. Кордон прорван.",
        "Это последний выпуск городской студии. Нас осталось двое.",
        "Всем, кто нас слышит: держитесь вместе. Не доверяйте укушенным.",
        "Электричество будет отключено. Повторяем: электричество будет отключено.",
        "Если вы слышите это - вы не одни. Удачи.",
    },
}

local tick = 0

local AUTOMATIC = "...Это автоматическое сообщение системы оповещения. Оставайтесь дома. Ждите помощи..."
local STATIC = "*шипение помех*"

function radio.broadcast(hours, tv)
    local day = math.floor(hours / 24) + 1
    local list = BROADCASTS[day]
    if list then
        local slot = math.floor(hours / radio.SLOT_HOURS)
        return (tv and "ТВ: " or "Радио: ") .. list[slot % #list + 1]
    end
    if tv then
        return nil
    end
    if day < radio.SILENCE_DAY and math.floor(hours / radio.SLOT_HOURS) % 3 == 0 then
        return "Радио: " .. AUTOMATIC
    end
    return STATIC
end

local function has_radio(pid)
    return inv.count(player.get_inventory(pid), "zomboid:radio") > 0
end

function radio.toggle(pid)
    local state = survival.get(pid)
    state.radio_on = not state.radio_on
    state.radio_slot = nil
    survival.notify(pid, state.radio_on and "Радио включено" or "Радио выключено")
    return state.radio_on
end

function radio.listen(pid)
    local state = survival.get(pid)
    local slot = math.floor(clock.hours / radio.SLOT_HOURS)
    if state.radio_slot == slot then
        return nil
    end
    state.radio_slot = slot
    local text = radio.broadcast(clock.hours, false)
    survival.notify(pid, text, text == STATIC and "#808080" or "#c0d8ff")
    if vc.is_client() and text == STATIC then
        local x, y, z = player.get_pos(pid)
        audio.play_sound("world/static", x, y, z, 0.4, 1.0)
    end
    return text
end

function radio.tick()
    tick = tick + 1
    if tick % 40 ~= 0 then
        return
    end
    for _, pid in ipairs(player.get_all()) do
        local state = survival.get(pid)
        if state.radio_on and not state.dead then
            if has_radio(pid) then
                radio.listen(pid)
            else
                state.radio_on = false
            end
        end
    end
end

return radio
