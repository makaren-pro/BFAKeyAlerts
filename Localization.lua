local BKA = BFAKeyAlerts

local clientLocale = GetLocale and GetLocale() or "enUS"
BKA.locale = clientLocale == "ruRU" and "ruRU" or "enUS"

local EN = {
    DRAG = "drag",
    READY = "READY",
    DOWN = "DOWN",
    COOLDOWN_FMT = "CD: %ss",
    UNAVAILABLE = "Unavailable",
    UNKNOWN_READY = "Readiness not confirmed yet",
    GROUP_CONTROL = "Group control",
    GROUP_CONTROL_HEADER = "GROUP CONTROL",
    KICK_SUMMARY_FMT = "K %d/%d  |  CC %d",
    KEYSTONE_TIMER = "Keystone timer",
    DUNGEON = "Dungeon",
    KEY_PREVIEW_BOSS = "Unlocked - drag the blue handle above",
    MYTHIC_SETUP = "MYTHIC+  /  POSITION SETUP",
    MYTHIC_KEY_FMT = "MYTHIC+  /  KEY +%d",
    AFFIX_WAIT = "Affixes appear after the key starts",
    FORCES_FMT = "Forces %.1f%%  |  remaining %.1f%%",
    FORCES_EMPTY = "ENEMY FORCES   -",
    BOSSES_FMT = "BOSSES   %d / %d   |   REMAINING %d",
    BOSSES_DONE = "All bosses defeated",
    WAIT_OBJECTIVES = "Waiting for dungeon objectives...",
    FOOTER_FMT = "Elapsed %s   |   Deaths %d   |   Penalty %s",
    YOU = "YOU",
    TANK = "TANK",
    FIXED = "FIXED",
    LOCKED = "LOCKED",
    TRACK = "TRACK",
    TRACKING = "TRACKING",
    SOON = "SOON",
    YOU_ACTION_FMT = "YOU - %s",
    SOON_ACTION_FMT = "SOON - %s",
    ACTION_SOON_FMT = "%s SOON",
    SPELL_FALLBACK = "Spell %s",
    UPDATE_AVAILABLE_FMT = "New version %s is available. GitHub: %s",
    ON = "ON",
    OFF = "OFF",
    ADDON = "addon",
    CENTER_ALERTS = "center alerts",
    NAMEPLATES = "nameplates",
    GROUP_KICKS = "group kicks",
    SOUND = "sound",
    FRONTAL_DETAILS = "frontal target details",
    CLICKABLE_NAMEPLATES = "clickable nameplate alerts",
    SOUND_RESET_DONE = "Combat sound actions reset to ON",
    SLASH_HELP = "/bka config, alerts on|off, plates on|off, kicks on|off, keytimer on|off, frontal on|off, plateclick on|off|status, soundpreview <name|all|keyupgrade>, soundreset, unlock, lock, on|off, sound on|off",
    PLATE_API_UNAVAILABLE = "plateclick: BFA nameplate click API unavailable",
    REMAINING = "remaining",
}

local RU = {
    DRAG = "перетащи",
    READY = "ГОТОВО",
    DOWN = "НЕДОСТУПНО",
    COOLDOWN_FMT = "КД: %sс",
    UNAVAILABLE = "Недоступно",
    UNKNOWN_READY = "Готовность пока не подтверждена",
    GROUP_CONTROL = "Контроль группы",
    GROUP_CONTROL_HEADER = "КОНТРОЛЬ ГРУППЫ",
    KICK_SUMMARY_FMT = "КИК %d/%d  |  КОНТРОЛЬ %d",
    KEYSTONE_TIMER = "Таймер ключа",
    DUNGEON = "Подземелье",
    KEY_PREVIEW_BOSS = "Разблокировано - перетащи полоску сверху",
    MYTHIC_SETUP = "MYTHIC+  /  НАСТРОЙКА ПОЗИЦИИ",
    MYTHIC_KEY_FMT = "MYTHIC+  /  КЛЮЧ +%d",
    AFFIX_WAIT = "Аффиксы появятся после запуска ключа",
    FORCES_FMT = "Силы %.1f%%  |  осталось %.1f%%",
    FORCES_EMPTY = "СИЛЫ ПРОТИВНИКА   -",
    BOSSES_FMT = "БОССЫ   %d / %d   |   ОСТАЛОСЬ %d",
    BOSSES_DONE = "Все боссы повержены",
    WAIT_OBJECTIVES = "Ожидание целей подземелья...",
    FOOTER_FMT = "Прошло %s   |   Смертей %d   |   Штраф %s",
    YOU = "ТЫ",
    TANK = "ТАНК",
    FIXED = "ФИКСИРОВАН",
    LOCKED = "ЗАФИКСИРОВАН",
    TRACK = "СЛЕДИТ",
    TRACKING = "СЛЕДИТ ЗА ЦЕЛЬЮ",
    SOON = "СКОРО",
    YOU_ACTION_FMT = "ТЫ - %s",
    SOON_ACTION_FMT = "СКОРО - %s",
    ACTION_SOON_FMT = "%s СКОРО",
    SPELL_FALLBACK = "Спелл %s",
    UPDATE_AVAILABLE_FMT = "Доступна новая версия %s. GitHub: %s",
    ON = "ВКЛ",
    OFF = "ВЫКЛ",
    ADDON = "аддон",
    CENTER_ALERTS = "центральные предупреждения",
    NAMEPLATES = "неймплейты",
    GROUP_KICKS = "кики группы",
    SOUND = "звук",
    FRONTAL_DETAILS = "цель и режим фронтала",
    CLICKABLE_NAMEPLATES = "кликабельные алерты на неймплейтах",
    SOUND_RESET_DONE = "Боевые звуки сброшены и включены",
    SLASH_HELP = "/bka config, alerts on|off, plates on|off, kicks on|off, keytimer on|off, frontal on|off, plateclick on|off|status, soundpreview <name|all|keyupgrade>, soundreset, unlock, lock, on|off, sound on|off",
    PLATE_API_UNAVAILABLE = "plateclick: API клика по неймплейтам BFA недоступен",
    REMAINING = "осталось",
}

local STRINGS = BKA.locale == "ruRU" and RU or EN

function BKA:L(key, ...)
    local value = STRINGS[key] or EN[key] or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

local RU_ACTIONS = {
    ["CAST"] = "КАСТ",
    ["KICK"] = "КИК",
    ["STOP"] = "СТОП",
    ["CC"] = "КОНТРОЛЬ",
    ["TURN"] = "ОТВЕРНИ",
    ["AOE"] = "АОЕ",
    ["FRONTAL"] = "ФРОНТАЛ",
    ["CLEAVE"] = "КЛИВ",
    ["MOVE"] = "ВЫЙДИ",
    ["MOVE MOBS"] = "ВЫВЕДИ МОБОВ",
    ["DODGE"] = "УКЛОНИСЬ",
    ["GTFO"] = "ВЫЙДИ",
    ["TARGET"] = "ЦЕЛЬ",
    ["TARGETED"] = "ЦЕЛЬ",
    ["DISPEL"] = "ДИСПЕЛ",
    ["PURGE"] = "ПУРЖ",
    ["SOOTHE"] = "УСМИРИ",
    ["DEF"] = "СЕЙВ",
    ["DEFENSIVE"] = "СЕЙВ",
    ["HEAL"] = "ХИЛ",
    ["SOAK"] = "СОАК",
    ["SPREAD"] = "РАЗОЙДИСЬ",
    ["STACK"] = "СОБЕРИТЕСЬ",
    ["STACKS"] = "СТАКИ",
    ["RESET"] = "СБРОС",
    ["LOS"] = "ЛОС",
    ["RUN"] = "БЕГИ",
    ["FIXATE"] = "ФИКСАЦИЯ",
    ["KITE"] = "КАЙТ",
    ["PREWARN"] = "СКОРО",
    ["PREPARE"] = "ПРИГОТОВЬСЯ",
    ["ORB"] = "СФЕРА",
    ["INFO"] = "ИНФО",
    ["WATCH"] = "СЛЕДИ",
    ["BURSTING"] = "ВЗРЫВНОЙ",
    ["STAGE"] = "ЭТАП",
    ["STAGE 2"] = "ЭТАП 2",
    ["ADD"] = "АДД",
    ["ADDS"] = "АДДЫ",
    ["WITHDRAW"] = "ОТХОД",
    ["RESUME"] = "ПРОДОЛЖАЙ",
    ["ORDNANCE"] = "БОЕПРИПАС",
    ["BURROW"] = "ЗАРЫВАНИЕ",
    ["INTERMISSION"] = "ПЕРЕХОДКА",
    ["SPEARS ACTIVE"] = "КОПЬЯ АКТИВНЫ",
    ["RUN / KITE"] = "БЕГИ / КАЙТ",
    ["CC / STOP"] = "КОНТРОЛЬ / СТОП",

    ["SOAK - TAINTED BLOOD"] = "СОАК - ЗАРАЖЕННАЯ КРОВЬ",
    ["PURGE - CLAWS"] = "ПУРЖ - КОГТИ",
    ["DISPEL - MOLTEN GOLD"] = "ДИСПЕЛ - РАСПЛАВЛЕННОЕ ЗОЛОТО",
    ["KILL - BARREL"] = "УБЕЙ - БОЧКА",
    ["SOAK - GOOD CRIT BREW"] = "СОАК - НАПИТОК КРИТА",
    ["SOAK - GOOD HASTE BREW"] = "СОАК - НАПИТОК СКОРОСТИ",
    ["MOVE - BAD BREW"] = "ВЫЙДИ - ПЛОХОЙ НАПИТОК",
    ["STACK - GOLD"] = "СОБЕРИТЕСЬ - ЗОЛОТО",
    ["CC - GOLD ADDS"] = "КОНТРОЛЬ - ЗОЛОТЫЕ АДДЫ",
    ["FIND - COFFIN"] = "НАЙДИ - ГРОБ",
    ["RUN - AGAINST WAVE"] = "БЕГИ - ПРОТИВ ВОЛНЫ",
    ["MOVE MOBS - OUT OF WARD"] = "ВЫВЕДИ МОБОВ - ИЗ ЗОНЫ",
    ["KITE - VOID ORBS"] = "КАЙТ - СФЕРЫ БЕЗДНЫ",
    ["BREAK - MINDBENDER"] = "СЛОМАЙ - МАЙНДБЕНДЕР",
    ["DISPEL - MIND REND"] = "ДИСПЕЛ - РАЗРЫВ РАЗУМА",
    ["MOVE BOSS - OUT OF GATE"] = "ВЫВЕДИ БОССА - ИЗ ВРАТ",
    ["DODGE - TENTACLE"] = "УКЛОНИСЬ - ЩУПАЛЬЦЕ",
    ["SWAP - SHIELDED BOSS"] = "СМЕНИ ЦЕЛЬ - БОСС ПОД ЩИТОМ",
    ["SPREAD - 8Y"] = "РАЗОЙДИСЬ - 8 М",
    ["PUNT - BOMBS"] = "ОТКИНЬ - БОМБЫ",
    ["CC - EARTHRAGER"] = "КОНТРОЛЬ - EARTHRAGER",
    ["KILL - INFUSED ADD"] = "УБЕЙ - УСИЛЕННЫЙ АДД",
    ["DEFENSIVE - FIRE ROUNDS"] = "СЕЙВ - ОГНЕННЫЕ ПАТРОНЫ",
    ["MOVE - KNOCKBACK ROUNDS"] = "ВЫЙДИ - ОТБРАСЫВАЮЩИЕ ПАТРОНЫ",
    ["MOVE - BARRELS"] = "ВЫЙДИ - БОЧКИ",
    ["DISPEL - NO BARREL"] = "ДИСПЕЛ - БЕЗ БОЧКИ",
    ["SOAK - CLEANSE BLOOD"] = "СОАК - ОЧИСТИ КРОВЬ",
    ["CLEAR - SPORES"] = "ОЧИСТИ - СПОРЫ",
    ["DODGE - PODS"] = "УКЛОНИСЬ - КАПСУЛЫ",
    ["KILL - SOUL THORNS"] = "УБЕЙ - ШИПЫ ДУШИ",
    ["DEFENSIVE - STACK RESET"] = "СЕЙВ - СБРОС СТАКОВ",
    ["FOCUS - IRIS BOSS"] = "ФОКУС - БОСС С ИРИСОМ",
    ["DEFENSIVE - DIRE RITUAL"] = "СЕЙВ - РИТУАЛ",
    ["KILL - SERVANTS"] = "УБЕЙ - СЛУГИ",
    ["ADDS - KILL"] = "АДДЫ - УБЕЙ",
    ["ADD - KILL"] = "АДД - УБЕЙ",
    ["BURN - CORPSES"] = "СОЖГИ - ТРУПЫ",
    ["KITE - IRON GAZE"] = "КАЙТ - ЖЕЛЕЗНЫЙ ВЗГЛЯД",
    ["PICK - ORDNANCE"] = "ПОДБЕРИ - БОЕПРИПАС",
    ["DODGE - BREAK WATER"] = "УКЛОНИСЬ - ВОЛНА",
    ["LOS - STATUE"] = "ЛОС - СТАТУЯ",
}

function BKA:LocalizeAction(action)
    if action == nil then return "" end
    local key = string.upper(tostring(action))
    key = string.gsub(key, "_", " ")
    key = string.gsub(key, "%s+", " ")
    key = string.gsub(key, "^%s+", "")
    key = string.gsub(key, "%s+$", "")
    if self.locale == "ruRU" then return RU_ACTIONS[key] or key end
    if key == "GTFO" then return "MOVE" end
    return key
end

function BKA:LocalizeToken(value)
    if value == "YOU" then return self:L("YOU") end
    if value == "TANK" then return self:L("TANK") end
    return self:LocalizeDetail(value)
end

function BKA:LocalizeFrontalState(value)
    if not value then return nil end
    if value == "FIXED" then return self:L("FIXED") end
    if value == "LOCKED" then return self:L("LOCKED") end
    if value == "TRACK" then return self:L("TRACK") end
    if value == "TRACKING" then return self:L("TRACKING") end
    return value
end

local RU_DETAILS = {
    ["Fixed frontal"] = "Фиксированный фронтал",
    ["Frontal on teammate"] = "Фронтал в союзника",
    ["Personal locked frontal"] = "Фронтал в тебя с фиксацией",
    ["Personal tracking frontal"] = "Фронтал следит за тобой",
    ["Frontal prediction"] = "Скоро фронтал",
    ["Active interrupt"] = "Активный кик",
    ["Council stage"] = "Этап совета",
    ["Stage 2"] = "Этап 2",
    ["Viq'Goth stage"] = "Этап Вик'Гота",
    ["Intermission"] = "Переходка",
    ["Intermission over"] = "Переходка закончилась",
    ["Heart Guardian"] = "Страж сердца",
    ["Plague Doctor"] = "Чумной доктор",
    ["Demolishing Terror"] = "Разрушительный ужас",
    ["Hoodoo Hexer"] = "Колдун худу",
    ["OVER"] = "ЗАКОНЧИЛОСЬ",
    ["SPAWNED"] = "ПОЯВИЛСЯ",
}

function BKA:LocalizeDetail(value)
    if value == nil then return "" end
    local text = tostring(value)
    if self.locale ~= "ruRU" then return text end
    if RU_DETAILS[text] then return RU_DETAILS[text] end
    local count = string.match(text, "^(%d+)%s+remaining$")
    if count then return count .. " " .. self:L("REMAINING") end
    local stage = string.match(text, "^Stage%s+(%d+)$")
    if stage then return "Этап " .. stage end
    local demolisher = string.match(text, "^Demolishing Terror%s+(%d+)$")
    if demolisher then return "Разрушительный ужас " .. demolisher end
    return text
end

local SPELL_ALIASES = {
    CURSED_PULSE = {
        ["Cursed Pulse"] = true,
        ["Проклятый импульс"] = true,
        ["Проклятый пульс"] = true,
    },
}

function BKA:IsSpellAlias(aliasKey, spellName)
    if not spellName then return false end
    local aliases = SPELL_ALIASES[aliasKey]
    return aliases and aliases[spellName] == true or false
end
