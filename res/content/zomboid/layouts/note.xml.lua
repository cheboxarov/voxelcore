local lore = require "zomboid:lore"

function on_open()
    local story = lore.STORIES[lore.current[hud.get_player()]]
    document.title.text = story and story.title or ""
    document.text.text = story and story.text or ""
end
