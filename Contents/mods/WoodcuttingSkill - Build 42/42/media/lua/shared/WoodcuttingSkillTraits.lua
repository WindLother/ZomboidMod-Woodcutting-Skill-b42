-- WoodcuttingSkillTraits.lua (Shared / Build 42.19)

require "WoodcuttingSkillDefinitions"
require "Foraging/forageSkills"

local WOODCUTTER_TRAIT_ID = "woodcuttingskill:woodcutter"

local function findTraitDefinition(name)
    local definitions = CharacterTraitDefinition.getTraits()
    for i = 0, definitions:size() - 1 do
        local definition = definitions:get(i)
        if definition:getType():getName():lower() == name:lower() then
            return definition
        end
    end
    return nil
end

local function addTraitBoost(characterTrait, amount)
    local perk = Woodcutting.getPerk()
    if not characterTrait or not perk then return end
    local definition = CharacterTraitDefinition.getCharacterTraitDefinition(characterTrait)
    if not definition then return end
    definition:addXPBoost(perk, amount)
    BaseGameCharacterDetails.SetTraitDescription(definition)
end

local function addProfessionBoost(characterProfession, amount)
    local perk = Woodcutting.getPerk()
    if not characterProfession or not perk then return end
    local definition = CharacterProfessionDefinition.getCharacterProfessionDefinition(characterProfession)
    if not definition then return end
    definition:addXPBoost(perk, amount)
    BaseGameCharacterDetails.SetProfessionDescription(definition)
end

local function addFirewoodSpecialisation(key, amount)
    local definitions = forageSystem and forageSystem.forageSkillDefinitions
    local definition = definitions and definitions[key]
    if not definition then return end
    definition.specialisations = definition.specialisations or {}
    definition.specialisations.Firewood = amount
end

local function registerWoodcutterTrait()
    local traitType = CharacterTrait.get(ResourceLocation.of(WOODCUTTER_TRAIT_ID))
    if not traitType then
        traitType = CharacterTrait.register(WOODCUTTER_TRAIT_ID)
    end

    local definition = CharacterTraitDefinition.getCharacterTraitDefinition(traitType)
    if not definition then
        definition = CharacterTraitDefinition.addCharacterTraitDefinition(
            traitType,
            "UI_trait_woodcutter",
            2,
            "UI_trait_woodcutterdesc",
            false,
            false
        )
    end

    local perk = Woodcutting.getPerk()
    if perk then definition:addXPBoost(perk, 1) end
    BaseGameCharacterDetails.SetTraitDescription(definition)

    forageSystem.forageSkillDefinitions.Woodcutter = {
        name = tostring(traitType),
        type = "trait",
        visionBonus = 0.2,
        weatherEffect = 5,
        darknessEffect = 2,
        specialisations = { Firewood = 10 },
    }
end

local function addOptionalModTraitBoost(name, amount, firewoodAmount)
    local definition = findTraitDefinition(name)
    local perk = Woodcutting.getPerk()
    if not definition or not perk then return end

    definition:addXPBoost(perk, amount)
    BaseGameCharacterDetails.SetTraitDescription(definition)

    if firewoodAmount then
        forageSystem.forageSkillDefinitions[name] = {
            name = tostring(definition:getType()),
            type = "trait",
            visionBonus = 0.2,
            weatherEffect = 5,
            darknessEffect = 2,
            specialisations = { Firewood = firewoodAmount },
        }
    end
end

local function initWoodcuttingSkillTraits()
    registerWoodcutterTrait()

    addTraitBoost(CharacterTrait.GARDENER, 1)
    addTraitBoost(CharacterTrait.HIKER, 1)
    addTraitBoost(CharacterTrait.SCOUT, 1)
    addFirewoodSpecialisation("Gardener", 5)
    addFirewoodSpecialisation("Hiker", 3)
    addFirewoodSpecialisation("Formerscout", 10)

    addProfessionBoost(CharacterProfession.LUMBERJACK, 3)
    addProfessionBoost(CharacterProfession.PARK_RANGER, 2)
    addProfessionBoost(CharacterProfession.FARMER, 1)

    local mods = getActivatedMods and getActivatedMods() or nil
    if not mods then return end

    if mods:contains("MoreSimpleTraits") or mods:contains("MoreSimpleTraitsMini")
        or mods:contains("MoreSimpleTraitsVanilla") or mods:contains("DynamicTraits") then
        addOptionalModTraitBoost("Cutter", 1, 10)
    end
    if mods:contains("ToadTraits") then
        addOptionalModTraitBoost("noxpaxe", 1, 10)
        addOptionalModTraitBoost("wildsman", 1, 5)
        addOptionalModTraitBoost("specfood", 2, 5)
        addOptionalModTraitBoost("speccrafting", 2)
    end
end

Events.OnGameBoot.Add(initWoodcuttingSkillTraits)
