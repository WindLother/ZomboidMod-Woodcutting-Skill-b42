-- WoodcuttingSkillDefinitions.lua (Shared)

Woodcutting = Woodcutting or {}

Woodcutting.testMode = false -- enable this for debug

-- Prints a message to the console/log exactly once per unique key, regardless of testMode.
-- Used to surface silent-failure paths (e.g. perk lookup) so bug reports come with actionable output.
local diagLoggedKeys = {}
function Woodcutting.diag(key, message)
    if diagLoggedKeys[key] then return end
    diagLoggedKeys[key] = true
    print("[Woodcutting][DIAG] " .. message)
end

Woodcutting.Settings = {
    ChanceOfExtrasOneIn = {
        -- chances must all be higher than 17 (max tree size 9 max perk level)
        Log = 40,
        TreeBranch = 35,
        Twigs = 30,

        Pinecone = 20, -- for pine trees only
        PineTreeExtra = 120, -- for pine trees only

        FruitTreeExtra = 80, -- for 'fruit' trees only
        Winter = 130 -- for 'fruit' trees only
    },

    cumulatedForagingAndWoodcuttingSkillLevelForFruit = 8, --Woodcutting + Foraging level required to spawn food
    skillLevelForNoSevereExhaustion = 8, --Woodcutting level required to disable severe exhaustion

    enduranceSavedPerPerkLevel = 0.07, -- 7%
    bonusConditionLowerOneInPerLevel = 1,
    caloriesSavedModifierPerLevel = 0.37,
    bonusAxeTreeDamagePerLevel = 2, -- flat addition, not multiplied

    xpMultiplier = 1,
    axeXpPerHit = 0.05,
    treeFelledXp = 5.0,
    axeXpOnTreeFelled = 1.0,

    -- ============================
    -- NOVOS PARÂMETROS DE DANO
    -- ============================
    -- Multiplicador base e por nível (aplica em QUALQUER arma afetada)
    damageBaseMultiplier  = 1.0,   -- 1.0 = padrão no nível 0
    damagePerLevel        = 0.15,  -- +15% por nível (ajuste livre)

    -- Teto de multiplicador (evita absurdos se quiser)
    damageMaxMultiplier   = 8.0,   -- até 8x do dano base

    -- Um-hit a partir deste nível (para atender à sua meta de 1 bate no nível 6–7)
    oneHitLevelThreshold  = 6,     -- nível de Woodcutting a partir do qual vira 1-hit
    oneHitTreeDamage      = 2000,  -- valor alto o suficiente para derrubar qualquer árvore em 1 golpe

    -- Restringir só a machados?
    onlyForAxes           = true,  -- true = só machados; false = qualquer HandWeapon
}

function Woodcutting.getPerk()
    if Perks.Woodcutting then
        Woodcutting.diag("getPerk:direct", "getPerk() resolved via Perks.Woodcutting direct field")
        return Perks.Woodcutting
    end
    if Perks.FromString then
        local perk = Perks.FromString("Woodcutting")
        if perk and perk ~= Perks.MAX then
            Woodcutting.diag("getPerk:fromstring", "getPerk() resolved via Perks.FromString('Woodcutting') -> " .. tostring(perk))
            return perk
        end
        Woodcutting.diag("getPerk:fromstring:fail", "Perks.FromString('Woodcutting') returned " .. tostring(perk) .. " (rejected, falling back to PerkFactory)")
    end
    if PerkFactory.getPerkFromName then
        local perk = PerkFactory.getPerkFromName("Woodcutting")
        if perk then
            Woodcutting.diag("getPerk:factory", "getPerk() resolved via PerkFactory.getPerkFromName('Woodcutting') -> " .. tostring(perk))
            return perk
        end
        Woodcutting.diag("getPerk:factory:fail", "PerkFactory.getPerkFromName('Woodcutting') returned nil")
    end
    Woodcutting.diag("getPerk:totalfail", "Woodcutting.getPerk() FAILED to resolve the Woodcutting perk through any method - all XP/damage/loot features are silently disabled")
    return nil
end

function Woodcutting.isAxe(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    local scriptItem = weapon:getScriptItem()
    return scriptItem ~= nil and scriptItem:containsWeaponCategory(WeaponCategory.AXE)
end

local currentTrees = setmetatable({}, { __mode = "k" })
local treeFelledCallbacks = {}

function Woodcutting.setCurrentTree(character, tree)
    if character then currentTrees[character] = tree end
end

function Woodcutting.getCurrentTree(character)
    return character and currentTrees[character] or nil
end

function Woodcutting.addOnTreeFelled(callback)
    if callback then table.insert(treeFelledCallbacks, callback) end
end

function Woodcutting.onTreeFelled(character, weapon, tree, treeSize, spriteName)
    Woodcutting.diag("onTreeFelled:dispatch", "Woodcutting.onTreeFelled() dispatched (treeSize=" .. tostring(treeSize) .. ", sprite=" .. tostring(spriteName) .. ") - " .. #treeFelledCallbacks .. " callback(s) registered")
    for _, callback in ipairs(treeFelledCallbacks) do
        local ok, err = pcall(callback, character, weapon, tree, treeSize, spriteName)
        if not ok then
            print("[Woodcutting] OnTreeFelled callback failed: " .. tostring(err))
        end
    end
end

Woodcutting.TreeFruitExtrasList = { -- except winter
    "Cherry",
    "Lemon",
    "Lime",
    "Grapefruit",
    "Peach",
    "Pear",
    "Apple",
    "Orange",
    "Banana",
    "Acorn",
    "DeadSquirrel",
}

Woodcutting.TreeFruitsWinterList = { -- for winter
    "DeadSquirrel",
}
Woodcutting.PineTreeExtrasList = { -- in all seasons
    "DeadSquirrel",
}
Woodcutting.TreePineSpriteDefinitions = {

    ["e_virginia_pineJUMBO_1_0"] = 1,
    ["e_virginia_pineJUMBO_1_1"] = 1,
    ["e_virginia_pine_1_0"] = 1,
    ["e_virginia_pine_1_1"] = 1,

    ["e_americanhollyJUMBO_1_1"] = 1,
    ["e_americanhollyJUMBO_1_0"] = 1,
    ["e_americanholly_1_1"] = 1,
    ["e_americanholly_1_0"] = 1,

    ["e_canadianhemlockJUMBO_1_0"] = 1,
    ["e_canadianhemlockJUMBO_1_1"] = 1,
    ["e_canadianhemlock_1_0"] = 1,
    ["e_canadianhemlock_1_1"] = 1,

}

function Woodcutting.noise(text)
    if Woodcutting.testMode then
        print(text)
    end
end

function Woodcutting.AdjustNatureAbundance()
    local chances = Woodcutting.Settings.ChanceOfExtrasOneIn
    if SandboxVars.NatureAbundance == 1 then -- very poor
        Woodcutting.Settings.ChanceOfExtrasOneIn.Log = math.floor(chances.Log * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.TreeBranch = math.floor(chances.TreeBranch * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Twigs = math.floor(chances.Twigs * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Pinecone = math.floor(chances.Pinecone * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.PineTreeExtra = math.floor(chances.PineTreeExtra * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.FruitTreeExtra = math.floor(chances.FruitTreeExtra * 1.2);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Winter = math.floor(chances.Winter * 1.2);
    elseif SandboxVars.NatureAbundance == 2 then -- poor
        Woodcutting.Settings.ChanceOfExtrasOneIn.Log = math.floor(chances.Log * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.TreeBranch = math.floor(chances.TreeBranch * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Twigs = math.floor(chances.Twigs * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Pinecone = math.floor(chances.Pinecone * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.PineTreeExtra = math.floor(chances.PineTreeExtra * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.FruitTreeExtra =  math.floor(chances.FruitTreeExtra * 1.1);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Winter = math.floor(chances.Winter * 1.2);
    elseif SandboxVars.NatureAbundance == 4 then -- abundant
        Woodcutting.Settings.ChanceOfExtrasOneIn.Log = math.floor(chances.Log * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.TreeBranch = math.floor(chances.TreeBranch * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Twigs = math.floor(chances.Twigs * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Pinecone = math.floor(chances.Pinecone * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.PineTreeExtra = math.floor(chances.PineTreeExtra * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.FruitTreeExtra =  math.floor(chances.FruitTreeExtra * 0.9);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Winter = math.floor(chances.Winter * 0.9);
    elseif SandboxVars.NatureAbundance == 5 then -- very abundant
        Woodcutting.Settings.ChanceOfExtrasOneIn.Log = math.floor(chances.Log * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.TreeBranch = math.floor(chances.TreeBranch * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Twigs = math.floor(chances.Twigs * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Pinecone = math.floor(chances.Pinecone * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.PineTreeExtra = math.floor(chances.PineTreeExtra * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.FruitTreeExtra = math.floor(chances.FruitTreeExtra * 0.8);
        Woodcutting.Settings.ChanceOfExtrasOneIn.Winter = math.floor(chances.Winter *0.8);
    end
end

Events.OnGameStart.Add(Woodcutting.AdjustNatureAbundance)
Events.OnServerStarted.Add(Woodcutting.AdjustNatureAbundance)

return Woodcutting
