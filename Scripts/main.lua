-- WeaknessTracker: shows the elements you have tried that turned out neutral, in the enemy
-- Affinities panel of FINAL FANTASY RESONANCE.
--
-- The game already remembers every element you hit a monster with, neutral ones included
-- (analyzedElments in the save, per monster type). The panel just never shows neutral,
-- because Neutral (eResistance 0) is missing from DisplayResistanceList in DA_UI_Resistance.
-- Each enemy's element list is built from that row list, so adding 0 to it is enough for the
-- game to list the neutral elements too, revealed or "?", with no tracking of our own.
--
-- What the game cannot do is draw them: ResistancePropertyMap has no Neutral entry, so the
-- resistance icon keeps its default, the Weakness burst. Adding the entry is not an option
-- (on UE4SS 3.0.1, TMap Contains/Find/Add crash the game natively, out of pcall's reach), so
-- each panel entry is fixed up after the game fills it instead, in WBP_BtlSkillResistEntry's
-- SetResistData:
--   neutral, tried     -> resistance icon hidden, leaving the plain element icon
--   neutral, not tried -> whole entry hidden (ShowUntested = true in config.ini keeps it, as "?")
--   anything else      -> left as the game drew it, restoring anything changed earlier, since
--                         the game reuses entry widgets
--
-- No path in this file contains a backslash (see Quiet Turn Voice for why).

local MOD = "[WeaknessTracker] "
local RESIST_NEUTRAL = 0
local ENTRY_CLASS = "WBP_BtlSkillResistEntry_C"
local CHECK_INTERVAL_MS = 1000
-- ESlateVisibility: takes no space at all.
local VISIBILITY_COLLAPSED = 1

local ELEMENTS = { [0] = "None", "Fire", "Ice", "Wind", "Earth", "Thunder", "Water", "Light", "Dark" }

local debugLog = false
local neutralRow = true
local showUntested = false
local entryHooked = false
local hookWorks = false
-- widget full name -> { entry = visibility, icon = visibility } as the game had them, so a
-- reused widget can be put back exactly.
local originalVisibility = {}

local function Log(msg)
    print(MOD .. msg .. "\n")
end

local function Debug(msg)
    if debugLog then Log(msg) end
end

-- TArray items arrive wrapped; get() unwraps them, plain values pass through.
local function Unwrap(v)
    if type(v) == "userdata" or type(v) == "table" then
        local ok, inner = pcall(function() return v:get() end)
        if ok then return inner end
    end
    return v
end

-- config.ini sits beside this mod's Scripts folder.
local function ModFilePath(file)
    local here = debug and debug.getinfo and debug.getinfo(1, "S")
    local src = ((here and here.source) or ""):gsub(string.char(92), "/")
    local scripts = src:match("^@(.*)/[^/]+$")
    if not scripts then return nil end
    return scripts .. "/../" .. file
end

-- Reads config.ini as key = value pairs, the same format Quiet Turn Voice uses.
local function LoadConfig()
    local cfg = {}
    local path = ModFilePath("config.ini")
    local f = path and io.open(path, "r")
    if not f then return cfg end
    for line in f:lines() do
        local k, v = line:match("^%s*([^;#%[=][^=]-)%s*=%s*(.-)%s*$")
        if k then cfg[k:lower()] = v end
    end
    f:close()
    return cfg
end

local function Flag(value, default)
    value = (value or ""):lower()
    if value == "true" then return true end
    if value == "false" then return false end
    return default
end

local assetReported = false

local function PatchResistanceAsset(da)
    local rows = da.DisplayResistanceList
    local hasRow = false
    rows:ForEach(function(_, item)
        if Unwrap(item) == RESIST_NEUTRAL then hasRow = true end
    end)
    if not hasRow then
        rows[rows:GetArrayNum() + 1] = RESIST_NEUTRAL
        if not assetReported then
            assetReported = true
            Log("added the Neutral row to " .. da:GetFullName())
        end
    end
end

local function PatchAssets()
    for _, da in ipairs(FindAllOf("CPP_DA_UI_Resistance") or {}) do
        if da:IsValid() then
            local ok, err = pcall(PatchResistanceAsset, da)
            if not ok then Debug("could not patch " .. da:GetFullName() .. ": " .. tostring(err)) end
        end
    end
end

-- Sets a widget's visibility, remembering the game's own value the first time.
local function SetVisibility(saved, slot, widget, visibility)
    if saved[slot] == nil then saved[slot] = widget:GetVisibility() end
    if widget:GetVisibility() ~= visibility then widget:SetVisibility(visibility) end
end

local function Restore(saved, slot, widget)
    if saved[slot] ~= nil and widget:GetVisibility() ~= saved[slot] then
        widget:SetVisibility(saved[slot])
    end
end

-- Brings one panel entry in line with its current ResistData.
local function FixEntry(entry)
    if not entry:IsValid() then return end
    local icon = entry.ResistanceBrush
    if not (icon and icon:IsValid()) then return end
    local key = entry:GetFullName()
    local saved = originalVisibility[key]
    if not saved then
        saved = {}
        originalVisibility[key] = saved
    end
    local data = entry.ResistData
    local neutral = data.resistance == RESIST_NEUTRAL
    if neutral and not data.bIsAnalyzed and not showUntested then
        SetVisibility(saved, "entry", entry, VISIBILITY_COLLAPSED)
        Restore(saved, "icon", icon)
    elseif neutral then
        Restore(saved, "entry", entry)
        SetVisibility(saved, "icon", icon, VISIBILITY_COLLAPSED)
        Debug("neutral entry: " .. (ELEMENTS[data.element] or tostring(data.element))
            .. (data.bIsAnalyzed and " (tried)" or " (not tried)"))
    else
        Restore(saved, "entry", entry)
        Restore(saved, "icon", icon)
    end
end

local function FixAllEntries()
    for _, entry in ipairs(FindAllOf(ENTRY_CLASS) or {}) do
        local ok, err = pcall(FixEntry, entry)
        if not ok then Debug("entry fix failed: " .. tostring(err)) end
    end
end

-- SetResistData is a Blueprint function, so it can only be hooked once its class is loaded,
-- which is the first time the panel is built. Until then each check tries again, and the
-- entries already on screen are fixed directly.
local function TryHookEntry()
    if entryHooked then return end
    local entry = FindFirstOf(ENTRY_CLASS)
    if not (entry and entry:IsValid()) then return end
    local classPath = entry:GetClass():GetFullName():match("^%S+%s+(.+)$")
    if not classPath then return end
    local fnPath = classPath .. ":SetResistData"
    local ok, err = pcall(RegisterHook, fnPath, function(self)
        local fixed, fixErr = pcall(FixEntry, self:get())
        if not fixed then Debug("entry fix failed: " .. tostring(fixErr)) end
    end)
    entryHooked = true
    hookWorks = ok
    if ok then
        Log("hooked " .. fnPath)
    else
        Log("could not hook " .. fnPath .. ", falling back to the periodic check: " .. tostring(err))
    end
end

local function Refresh()
    ExecuteInGameThread(function()
        if not neutralRow then return end
        PatchAssets()
        if entryHooked and hookWorks then return end
        local ok, err = pcall(TryHookEntry)
        if not ok then Debug("hook attempt failed: " .. tostring(err)) end
        -- Until the hook is in, and always if it could not be set, entries are fixed here.
        FixAllEntries()
    end)
end

LoopAsync(CHECK_INTERVAL_MS, function()
    Refresh()
    return false
end)

local cfg = LoadConfig()
debugLog = Flag(cfg.debug, false)
neutralRow = Flag(cfg.neutralrow, true)
showUntested = Flag(cfg.showuntested, false)
Log("loaded" .. (neutralRow and "" or ", Neutral row off") .. (debugLog and ", debug logging on" or ""))
