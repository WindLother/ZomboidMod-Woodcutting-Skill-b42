-- WoodcuttingExtraLoot.lua (Server)
-- Extra loot when hitting medium/large trees; chances scale with skill and NatureAbundance.
-- Pine extras are restricted to pine trees (detected via sprite).
-- Fruit extras are gated by skill + season; available from any medium/large tree.

require "WoodcuttingSkillDefinitions"

local function isWinter()
    local gt = getGameTime()
    local m = gt:getMonth() -- 0=jan ... 11=dec
    return (m == 11) or (m == 0) or (m == 1)
end

local function effectiveOneIn(baseOneIn, skillBonus)
    return math.max(2, math.floor((baseOneIn or 999) - (skillBonus or 0)))
end

local function giveItem(itemFullType, player)
    if not itemFullType or not ScriptManager.instance:FindItem(itemFullType) then
        if Woodcutting.testMode then
            print(string.format("[WoodcuttingLoot] Missing item %s", tostring(itemFullType)))
        end
        return false
    end
    player:getInventory():AddItem(itemFullType)
    return true
end

local function tryGive(itemFullType, oneIn, player)
    if oneIn and oneIn >= 2 and ZombRand(oneIn) == 0 then
        if not giveItem(itemFullType, player) then return false end
        if Woodcutting.testMode then
            print(string.format("[WoodcuttingLoot] Granted %s (1/%d)", itemFullType, oneIn))
        end
        return true
    end
    return false
end

local function isPineTree(spriteName)
    local name = spriteName
    return name ~= nil and Woodcutting.TreePineSpriteDefinitions[name] ~= nil
end

local function onTreeFelled(character, weapon, tree, treeSize, spriteName)
    if not character or not weapon then return end

    -- Only give extras from medium or large trees (size >= 5 out of 9).
    -- If size is undetectable, allow by default to avoid silently breaking the feature.
    if treeSize and treeSize < 5 then return end

    local S    = Woodcutting.Settings
    local woodcuttingPerk = Woodcutting.getPerk()
    if not woodcuttingPerk then return end
    local lvlW = character:getPerkLevel(woodcuttingPerk) or 0
    local lvlF = character:getPerkLevel(Perks.PlantScavenging) or 0
    local sum  = lvlW + lvlF
    local bonus = sum
    local c    = S.ChanceOfExtrasOneIn

    -- General extras: any medium/large tree
    tryGive("Base.Log",        effectiveOneIn(c.Log,        bonus), character)
    tryGive("Base.TreeBranch2", effectiveOneIn(c.TreeBranch, bonus), character)
    tryGive("Base.Twigs",      effectiveOneIn(c.Twigs,      bonus), character)

    -- Pine-specific extras: only when hitting a detected pine tree
    if isPineTree(spriteName) then
        tryGive("Base.Pinecone", effectiveOneIn(c.Pinecone, bonus), character)

        local oneInPineExtra = effectiveOneIn(c.PineTreeExtra, bonus)
        if ZombRand(oneInPineExtra) == 0 then
            local pool = Woodcutting.PineTreeExtrasList or {}
            if #pool > 0 then
                local pick = pool[ZombRand(#pool) + 1]
                local map  = { DeadSquirrel = "Base.DeadSquirrel" }
                local item = map[pick]
                if item then giveItem(item, character) end
            end
        end
    end

    -- Fruit/finds: any medium/large tree, gated by season + cumulated skill
    if isWinter() then
        local oneInWinter = effectiveOneIn(c.Winter, bonus)
        if ZombRand(oneInWinter) == 0 then
            local pool = Woodcutting.TreeFruitsWinterList or {}
            if #pool > 0 then
                local pick = pool[ZombRand(#pool) + 1]
                local map  = { DeadSquirrel = "Base.DeadSquirrel" }
                local item = map[pick]
                if item then giveItem(item, character) end
            end
        end
    else
        local oneInFruit = effectiveOneIn(c.FruitTreeExtra, bonus)
        if ZombRand(oneInFruit) == 0 and sum >= (S.cumulatedForagingAndWoodcuttingSkillLevelForFruit or 0) then
            local pool = Woodcutting.TreeFruitExtrasList or {}
            if #pool > 0 then
                local pick = pool[ZombRand(#pool) + 1]
                local map = {
                    Cherry       = "Base.Cherry",
                    Lemon        = "Base.Lemon",
                    Lime         = "Base.Lime",
                    Grapefruit   = "Base.Grapefruit",
                    Peach        = "Base.Peach",
                    Pear         = "Base.Pear",
                    Apple        = "Base.Apple",
                    Orange       = "Base.Orange",
                    Banana       = "Base.Banana",
                    Acorn        = "Base.Acorn",
                    DeadSquirrel = "Base.DeadSquirrel",
                }
                local item = map[pick]
                if item then giveItem(item, character) end
            end
        end
    end
end

Woodcutting.addOnTreeFelled(onTreeFelled)
