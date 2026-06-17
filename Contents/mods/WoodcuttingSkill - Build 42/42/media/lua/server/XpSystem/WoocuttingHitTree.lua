-- WoodCuttingHitTree.lua (Server / XPSystem)

require "WoodcuttingSkillDefinitions"

local function addWoodcuttingXP(character, handWeapon)
    Woodcutting.diag("OnWeaponHitTree:fired", "OnWeaponHitTree event fired (weapon=" .. tostring(handWeapon and handWeapon:getType()) .. ")")

    if not character or not handWeapon or handWeapon:getType() == "BareHands" then return end

    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then
        Woodcutting.diag("addWoodcuttingXP:noperk", "addWoodcuttingXP() bailed: Woodcutting.getPerk() returned nil")
        return
    end

    local settings = Woodcutting.Settings
    local multiplier = settings.xpMultiplier or 1
    local isAxe = Woodcutting.isAxe(handWeapon)
    local xpAmount = (isAxe and 0.2 or 0.1) * multiplier
    character:getXp():AddXP(woodcuttingPerk, xpAmount)
    Woodcutting.diag("addWoodcuttingXP:granted", "Granted " .. tostring(xpAmount) .. " Woodcutting XP (isAxe=" .. tostring(isAxe) .. ", multiplier=" .. tostring(multiplier) .. ")")

    if isAxe and (settings.axeXpPerHit or 0) > 0 then
        character:getXp():AddXP(Perks.Axe, settings.axeXpPerHit * multiplier)
    end
end

-- Per tree hit, chance to save 1 weapon condition point scales with Woodcutting level.
-- Base: 1 in 10 at level 1; 1 in 2 (capped) at level 9+.
-- bonusConditionLowerOneInPerLevel controls how fast the OneIn value drops per level.
local function saveWeaponCondition(character, weapon)
    if not character or not weapon then return end
    if not instanceof(weapon, "HandWeapon") then return end
    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then return end
    local lvl = character:getPerkLevel(woodcuttingPerk) or 0
    if lvl == 0 then return end
    local S      = Woodcutting.Settings
    local bonus  = lvl * (S.bonusConditionLowerOneInPerLevel or 0)
    local oneIn  = math.max(2, math.floor(10 - bonus))
    if ZombRand(oneIn) == 0 then
        local curCond = weapon:getCondition()
        local maxCond = weapon:getConditionMax()
        if curCond < maxCond then
            weapon:setCondition(curCond + 1)
        end
    end
end

local function addTreeFelledXP(character, weapon)
    Woodcutting.diag("onTreeFelled:addTreeFelledXP", "addTreeFelledXP() callback invoked")

    if not character or not weapon then return end

    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then
        Woodcutting.diag("addTreeFelledXP:noperk", "addTreeFelledXP() bailed: Woodcutting.getPerk() returned nil")
        return
    end

    local settings = Woodcutting.Settings
    local multiplier = settings.xpMultiplier or 1
    local woodcuttingXp = (settings.treeFelledXp or 0) * multiplier
    local axeXp = (settings.axeXpOnTreeFelled or 0) * multiplier

    if woodcuttingXp > 0 then
        character:getXp():AddXP(woodcuttingPerk, woodcuttingXp)
        Woodcutting.diag("addTreeFelledXP:granted", "Granted " .. tostring(woodcuttingXp) .. " Woodcutting XP on tree felled")
    end
    if axeXp > 0 and Woodcutting.isAxe(weapon) then
        character:getXp():AddXP(Perks.Axe, axeXp)
    end

    local modData = character:getModData()
    modData.treekills = (modData.treekills or 0) + 1
end

Events.OnWeaponHitTree.Add(addWoodcuttingXP)
Events.OnWeaponHitTree.Add(saveWeaponCondition)
Woodcutting.addOnTreeFelled(addTreeFelledXP)
