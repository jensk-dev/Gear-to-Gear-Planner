local ADDON_NAME, ADDON_TABLE = ...;

local ENCHANTS = ADDON_TABLE.mappings.enchants;
local QUIVERS = ADDON_TABLE.mappings.quivers;

local b64 = ADDON_TABLE.b64;

local function GetTalentTabArray(tab_index)
    local tab_array = {};
    local talents_count = GetNumTalents(tab_index);

    for i=1,talents_count do
        local current_rank = select(5, GetTalentInfo(tab_index, i))
        table.insert(tab_array, current_rank);
    end

    local last_number = 0;
    for i,v in pairs(tab_array) do
        if v > 0 then
            last_number = i;
        end
    end

    for i=last_number + 1,#tab_array do
        tab_array[i] = nil;
    end

    return tab_array;
end

local function Encode(slots)
    local bit_helper_enchant = 0x80;
    local bit_helper_random_enchant = 0x40;
    local bit_validity_check = 0x2;

    local player_level = tonumber(UnitLevel('player'));

    local ids_table = { bit_validity_check, player_level };

    local talent_char_array = {};

    for i=1,3 do
        local talent_string = GetTalentTabArray(i);
        for _,v in pairs(talent_string) do
            table.insert(talent_char_array, v);
        end
        table.insert(talent_char_array, 15);
    end

    table.insert(ids_table, math.ceil(#talent_char_array / 2));

    for i=1,#talent_char_array,2 do
        local char = talent_char_array[i];
        local next_char = talent_char_array[i+1] or 0;

        char = bit.lshift(char, 0x4);
        char = bit.bor(char, next_char);
        table.insert(ids_table, char);
    end

    for i,v in pairs(slots) do
        local item_id = v.item;
        local enchant_id = v.enchant;
        local random_enchant_id = v.random_enchant;

        if (enchant_id > 0) then
            i = bit.bor(i, bit_helper_enchant);
        end
        if (random_enchant_id > 0) then
            i = bit.bor(i, bit_helper_random_enchant);
        end
        table.insert(ids_table, i);
        table.insert(ids_table, bit.band(bit.rshift(item_id, 0x8), 0xFF));
        table.insert(ids_table, bit.band(item_id, 0xFF));
        if (enchant_id > 0) then
            table.insert(ids_table, bit.band(bit.rshift(enchant_id, 0x8), 0xFF));
            table.insert(ids_table, bit.band(enchant_id, 0xFF));
        end
        if (random_enchant_id > 0) then
            table.insert(ids_table, bit.band(bit.rshift(random_enchant_id, 0x8), 0xFF));
            table.insert(ids_table, bit.band(random_enchant_id, 0xFF));
        end
    end

    local result = '';
    for _,v in pairs(ids_table) do
        result = result .. string.char(v);
    end

    return string.gsub(string.gsub(string.gsub(b64.enc(result), '%+', '-'), '/', '_'), '=', '');
end

local function GetURLPrefix()
    local playable_races = { 'human', 'orc', 'dwarf', 'night-elf', 'undead', 'tauren', 'gnome', 'troll' }
    local player_race  = select(3, UnitRace('player'));
    local player_class = select(2, UnitClass('player')):lower();
    return string.format("%s/%s", player_class, playable_races[player_race]);
end

local function GetItemInfoFromVarargs(...)
    local item_id = select(2, ...);
    local enchant_id = select(3, ...);
    local random_enchant_id = select(8, ...); 
    return item_id, enchant_id, random_enchant_id;
end

local function GetSlotInfo(slot_id)
    local item_link = GetInventoryItemLink('player', slot_id);
    local item_id, enchant_id, random_enchant_id;
    local is_2_handed = false;

    if (item_link ~= nil) then
        is_2_handed = select(9, GetItemInfo(item_link)) == 'INVTYPE_2HWEAPON';
        item_id, enchant_id, random_enchant_id = GetItemInfoFromVarargs(strsplit(':', item_link));
    end

    item_id = tonumber(item_id) or 0;
    random_enchant_id = tonumber(random_enchant_id) or 0;

    --[[ See if slot_id is eligible for enchants ]]
    local spell_id = 0;
    if (ENCHANTS[slot_id] ~= nil) then
        --[[ Assign an enchant ]]
        spell_id = ENCHANTS[slot_id][tonumber(enchant_id)] or spell_id;
        if (is_2_handed) then
            spell_id = ENCHANTS[slot_id][0][tonumber(enchant_id)] or spell_id;
        end
    end

    return item_id, spell_id, random_enchant_id;
end

local function GetHunterBag()
    for i=20,23,1 do
        local bag_id = GetSlotInfo(i);
        if (QUIVERS[bag_id]) then
            return bag_id;
        end
    end
end

local function IterateSlots()
    local slots = {};

    -- Cycle through all gear slots
    for i=0,18,1 do
        slots[i] = {}; 
        slots[i].item, slots[i].enchant, slots[i].random_enchant = GetSlotInfo(i);
        if (slots[i].item == 0) then
            slots[i] = nil;
        end
    end

    -- always exclude shirt
    slots[4] = nil;
    if (GetHunterBag()) then
        slots[0] = {
            item = GetHunterBag(),
            enchant = 0,
            random_enchant = 0,
        }
    end

    return slots;
end

SLASH_GTGP1 = '/gtgp';
SlashCmdList["GTGP"] = function(msg)
    GTGP_FRAME:Show();
    GTGP_URL:HighlightText();

    local slots = IterateSlots();

    local hash = Encode(slots);
    local url_prefix = GetURLPrefix();
    local url = string.format("https://classic.wowhead.com/gear-planner/%s/%s", url_prefix, hash);

    GTGP_URL:SetText(url);
    GTGP_URL:SetCursorPosition(0);
end
