local _addonName = "LPA";
-- local _player, _realm = UnitName("player");

-- local MAX_MACROS = MAX_CHARACTER_MACROS + MAX_ACCOUNT_MACROS

local UTILS = {
  ["TableSize"] = function(T)
    local count = 0;
    for i, v in ipairs(T) do
      count = count + 1
    end
    return count;
  end
};


local SpellCache = {
  ["mounts"] = {}
};

-- Configuration
local _config = {
  --["bars"] = {2,3,4,5},
  ["initialized"] = false,
  ["store"] = {}
};

function println(...)
  local msg = "";

  for i, value in ipairs({...}) do
    if ( value ~= nil ) then
      if ( msg ~= "" ) then
        msg = msg .. ", "
      end
      msg = msg .. value;
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. _addonName .. "|r: " .. msg)
end

-- BEGIN LPA
LPA = {};

function LPA:init()
  if ( _config.initialized == false ) then
    if ( ElvUI ) then
      println("Using ElvUI bars: 2, 3, 4, 6");
      _config.bars = {2,3,4,6};
    else
      println("Using default bars: 2, 3, 4, 5")
      _config.bars = {2,3,4,5};
    end
    _config.initialized = true;
  end
end

function LPA:saveState()
  -- Reset Store
  table.wipe(_config.store);

  -- Save Actions
  local result, err = pcall(function()

  end);
  if ( result == false ) then
    error(err);
  end

  self:_iterateSlots(function(store, actionId)
    store[actionId] = nil;

    local type, id, subType, extraId = GetActionInfo(actionId);
    if ( type and id ) then
      local entry = {
        ["type"] = type,
        ["id"] = id,
        ["subType"] = subType,
        ["extraId"] = extraId
      };

      local spellName = "";
      if ( type == "spell" ) then
        local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(id);
        spellName = name;
      end

      -- println(actionId, type, id, spellName);
      store[actionId] = entry;
    end
  end);
end

function LPA:restoreState()
  if ( UTILS:TableSize(_config.store) == 0 ) then return end;

  -- Init
  ClearCursor();

  -- Disable Sound
  local soundToggle = GetCVar("Sound_EnableAllSound")
  SetCVar("Sound_EnableAllSound", 0)

  -- Restore Actions
  self:_iterateSlots(function(store, actionId)
    local action = store[actionId];
    local type, id = GetActionInfo(actionId);

    -- Clear Current Action Button
    if ( id or type ) then
      PickupAction(actionId);
      ClearCursor();
    end

    -- Restore Action
    if ( action ) then
      self:_restore(actionId, action, SpellCache);
    end
  end);

  -- Restore old sound setting
  SetCVar("Sound_EnableAllSound", soundToggle)
  _config.store = nil
end

function LPA:_updateSpellCache()
  -- clear cache
  table.wipe(SpellCache["mounts"]);

  -- get all collected mounts
  for index = 1, C_MountJournal.GetNumDisplayedMounts() do
    local _, spellId, _, _, _, _, _, _, _, _, isCollected, mountId = C_MountJournal.GetDisplayedMountInfo(index)
    if ( isCollected ) then
      SpellCache.mounts[mountId] = spellId;
    end
  end
end

function LPA:_restore(actionId, action, cache)
  -- println(action.type, action.id);

  if ( action.type == "spell" or action.type == "flyout" or action.type == "companion" ) then
    -- Spell, Flyout
    PickupSpell(action.id);
    PlaceAction(actionId);

  elseif ( action.type == "summonmount" ) then
    -- Mounts
    if ( cache.mounts[action.id] ) then
      local spellId = cache.mounts[action.id];
      PickupSpell(spellId);
      PlaceAction(actionId);
    end

  elseif ( action.type == "summonpet" ) then
    -- Pets
    C_PetJournal.PickupPet(action.id)
    PlaceAction(actionId);

  elseif ( action.type == "equipmentset" ) then
    -- Equimentsets
    PickupEquipmentSet(action.id);
    PlaceAction(actionId);

  elseif ( action.type == "item" ) then
    -- Items
    PickupItem(action.id);
    PlaceAction(actionId);

  elseif ( action.type == "macro" ) then
    -- Macro
    PickupMacro(action.id);
    PlaceAction(actionId);

  end

  ClearCursor();
end

function LPA:_iterateSlots(helper)
  if ( helper ~= nil ) then
    for i, bar in ipairs(_config.bars) do
      local startSlot = (bar - 1) * 12 + 1;
      for i = startSlot, startSlot + 11 do
        helper(_config.store, i)
      end
    end
  end
end

function LPA:clearBars()
  for bar = 1, 6 do
    local start = (bar - 1) * 12 + 1
    for actionId = start, start + 11 do
      PickupAction(actionId);
      ClearCursor();
    end
  end
end
-- END LPA

-- Register Events
local _frame = CreateFrame("Frame");
_frame:RegisterEvent("PLAYER_ENTERING_WORLD");
_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
_frame:RegisterEvent("UNIT_SPELLCAST_START");

_frame:SetScript("OnEvent", function(self, event, ...)
  local arg = {...};

  if ( event == "PLAYER_ENTERING_WORLD" ) then
    LPA:init()

  elseif ( event == "PLAYER_SPECIALIZATION_CHANGED" and arg[1] == "player" ) then
    -- println("Specialization changed, restore action bars ...");
    LPA:restoreState()

  elseif ( event == "UNIT_SPELLCAST_START" and arg[5] == 200749 ) then
    -- println("Changing specialization, save action bars ...");
    LPA:saveState()
    
  end
end)