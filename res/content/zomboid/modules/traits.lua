local traits = {}

traits.LIST = {
    {id = "strong", title = "Сильный", cost = 4, text = "Урон в ближнем бою +20%, отбрасывание +40%",
        mods = {melee_damage = 1.2, knockback = 1.4}, opposite = "weak"},
    {id = "athletic", title = "Выносливый", cost = 4, text = "Бег тратит на 30% меньше выносливости",
        mods = {sprint_stamina = 0.7}, opposite = "out_of_shape"},
    {id = "light_step", title = "Тихий шаг", cost = 3, text = "Шаги на 40% тише",
        mods = {noise = 0.6}, opposite = "clumsy"},
    {id = "fast_learner", title = "Быстро учится", cost = 5, text = "Опыт навыков +30%",
        mods = {xp = 1.3}, opposite = "slow_learner"},
    {id = "light_eater", title = "Малоежка", cost = 3, text = "Голод растёт на 25% медленнее",
        mods = {hunger = 0.75}, opposite = "hearty_appetite"},
    {id = "handy", title = "Мастер на все руки", cost = 3, text = "+1 к плотницкому делу, баррикады прочнее на 15%",
        mods = {barricade_hp = 1.15}, skills = {carpentry = 1}},
    {id = "weak", title = "Слабый", cost = -4, text = "Урон в ближнем бою -25%, отбрасывание -30%",
        mods = {melee_damage = 0.75, knockback = 0.7}},
    {id = "out_of_shape", title = "Не в форме", cost = -3, text = "Бег тратит на 40% больше выносливости",
        mods = {sprint_stamina = 1.4}},
    {id = "clumsy", title = "Неуклюжий", cost = -2, text = "Шаги на 50% громче",
        mods = {noise = 1.5}},
    {id = "slow_learner", title = "Медленно учится", cost = -4, text = "Опыт навыков -30%",
        mods = {xp = 0.7}},
    {id = "hearty_appetite", title = "Обжора", cost = -3, text = "Голод растёт на 30% быстрее",
        mods = {hunger = 1.3}},
    {id = "cowardly", title = "Трусливый", cost = -3,
        text = "Паника, когда рядом 3+ зомби: урон -30%, удары тратят на 50% больше выносливости",
        mods = {panic_damage = 0.7, panic_stamina = 1.5}},
    {id = "short_sighted", title = "Близорукий", cost = -2, text = "Всё вдали размыто",
        mods = {}},
    {id = "sleepyhead", title = "Соня", cost = -2, text = "Бодрость падает на 30% быстрее",
        mods = {energy = 1.3}},
}

local BY_ID = {}
for _, def in ipairs(traits.LIST) do
    BY_ID[def.id] = def
end

function traits.find(id)
    return BY_ID[id]
end

function traits.conflict(a, b)
    return BY_ID[a].opposite == b or BY_ID[b].opposite == a
end

function traits.has(state, id)
    return table.has(state.traits or {}, id)
end

function traits.mul(state, key)
    local m = 1.0
    for _, id in ipairs(state.traits or {}) do
        m = m * (BY_ID[id].mods[key] or 1.0)
    end
    return m
end

return traits
