-- Build 42.19 timed-action compatibility patches.

require "WoodcuttingSkillDefinitions"

print("[Woodcutting][DIAG] B42_TimedActionPacthes.lua chunk executed (file is being loaded)")
Woodcutting.diag("B42_TimedActionPacthes:fileloaded", "B42_TimedActionPacthes.lua chunk executed (file is being loaded)")

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function getWoodcuttingLevel(character)
    local perk = Woodcutting.getPerk()
    if not character or not perk then return 0 end
    return character:getPerkLevel(perk) or 0
end

local function scaleFiniteDuration(action, speedPerLevel, minimumMultiplier)
    local duration = action and action.maxTime
    if not duration or duration < 0 then return end

    local level = getWoodcuttingLevel(action.character)
    local multiplier = math.max(minimumMultiplier, 1.0 - speedPerLevel * level)
    action.maxTime = math.max(5, math.floor(duration * multiplier + 0.5))
end

local function refundEndurance(character, before, savedPerLevel)
    if not character or not before then return end
    local stats = character:getStats()
    if not stats then return end

    local after = stats:get(CharacterStat.ENDURANCE)
    local spent = math.max(0, before - after)
    if spent <= 0 then return end

    local level = getWoodcuttingLevel(character)
    local savedFraction = clamp(savedPerLevel * level, 0, 0.9)
    stats:add(CharacterStat.ENDURANCE, spent * savedFraction)

    local threshold = Woodcutting.Settings.skillLevelForNoSevereExhaustion
    if threshold and level >= threshold
        and stats:get(CharacterStat.ENDURANCE) < 0.15 then
        stats:set(CharacterStat.ENDURANCE, 0.15)
    end
end

local function getTreeSize(tree)
    if not tree then return nil end
    local hasOk, has = pcall(function() return tree:hasProperty("TreeSize") end)
    if not hasOk or not has then return nil end
    local ok, value = pcall(function() return tree:getProperty("TreeSize") end)
    return (ok and value) and tonumber(value) or nil
end

local function getTreeSpriteName(tree)
    if not tree then return nil end
    local ok, sprite = pcall(function() return tree:getSprite() end)
    if not ok or not sprite then return nil end
    local okName, name = pcall(function() return sprite:getName() end)
    return okName and name or nil
end

local function patchTimedAction(className, speedPerLevel, minimumMultiplier, savedPerLevel)
    local loaded = pcall(require, "TimedActions/" .. className)
    if not loaded then
        Woodcutting.diag("patch:requirefail:" .. className, "patchTimedAction(" .. className .. ") FAILED: require('TimedActions/" .. className .. "') errored")
        return
    end

    local class = _G[className]
    if not class then
        Woodcutting.diag("patch:noclass:" .. className, "patchTimedAction(" .. className .. ") FAILED: _G['" .. className .. "'] is nil after require - class is not a global, patch cannot apply")
        return
    end
    if class.__WDC_patched then return end
    class.__WDC_patched = true
    Woodcutting.diag("patch:applied:" .. className, "patchTimedAction(" .. className .. ") patched successfully")

    local originalNew = class.new
    local originalUseEndurance = class.useEndurance

    function class:new(character, ...)
        local action = originalNew(self, character, ...)
        scaleFiniteDuration(action, speedPerLevel, minimumMultiplier)
        return action
    end

    if originalUseEndurance then
        function class:useEndurance()
            local stats = self.character and self.character:getStats()
            local before = stats and stats:get(CharacterStat.ENDURANCE) or nil
            originalUseEndurance(self)
            refundEndurance(self.character, before, savedPerLevel)
        end
    end
end

-- OnWeaponHitTree fires BEFORE Java applies damage and removes the tree, so we cannot
-- check getObjectIndex() == -1 inside that callback. Instead, on every tree hit we record
-- the tree being hit, then register a one-shot OnTick handler. OnTick fires on the next
-- engine frame, by which point Java has already processed the damage and removed the tree
-- if the hit was lethal. trackedTrees caches size/sprite so we only look them up on first
-- hit of each tree, not on every swing.
local trackedTrees   = setmetatable({}, { __mode = "k" })  -- character → { tree, treeSize, spriteName }
local pendingChecks  = {}  -- character → { tree, weapon, treeSize, spriteName }
local onTickActive   = false

local function findAdjacentTree(character)
    local square = character and character:getCurrentSquare()
    local cell = square and getCell()
    if not cell then return nil end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            local tree = sq and sq:getTree()
            if tree and tree:getObjectIndex() >= 0 then
                return tree
            end
        end
    end
    return nil
end

local function onTickFelledCheck()
    Events.OnTick.Remove(onTickFelledCheck)
    onTickActive = false
    for character, data in pairs(pendingChecks) do
        if data.tree:getObjectIndex() == -1 then
            Woodcutting.diag("treeFelled:detected", "Detected felled tree via OnTick check (size=" .. tostring(data.treeSize) .. ", sprite=" .. tostring(data.spriteName) .. ")")
            Woodcutting.onTreeFelled(character, data.weapon, data.tree, data.treeSize, data.spriteName)
            trackedTrees[character] = nil
        end
    end
    pendingChecks = {}
end

local function checkTreeFelled(character, weapon)
    if not character then return end
    local current = findAdjacentTree(character)
    if not current then return end

    local cached = trackedTrees[character]
    local treeSize, spriteName
    if cached and cached.tree == current then
        treeSize, spriteName = cached.treeSize, cached.spriteName
    else
        treeSize    = getTreeSize(current)
        spriteName  = getTreeSpriteName(current)
        trackedTrees[character] = { tree = current, treeSize = treeSize, spriteName = spriteName }
    end

    pendingChecks[character] = { tree = current, weapon = weapon, treeSize = treeSize, spriteName = spriteName }
    if not onTickActive then
        Events.OnTick.Add(onTickFelledCheck)
        onTickActive = true
    end
end

Events.OnWeaponHitTree.Add(checkTreeFelled)

local function applyPatches()
    Woodcutting.diag("applyPatches:ran", "applyPatches() ran")

    local settings = Woodcutting.Settings or {}
    local savedPerLevel = settings.enduranceSavedPerPerkLevel or 0.07

    -- Tree chopping has duration -1 in 42.19 and must remain animation-driven.
    patchTimedAction("ISChopTreeAction", 0, 1, savedPerLevel)
    patchTimedAction("ISRemoveBush", 0.10, 0.30, savedPerLevel)
end

Events.OnGameBoot.Add(applyPatches)
Events.OnGameStart.Add(applyPatches)
Events.OnServerStarted.Add(applyPatches)
