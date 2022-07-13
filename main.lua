--All code written by Aaron Cohen

local stackable_stew = RegisterMod("stackable_stew", 1)
stackable_stew.STEW_ITEM_ID = Isaac.GetItemIdByName("Stackable Stew")
local json = require("json")



-- VARIABLES
local numStews = 0
local damages = {}
local time = 0
local renderX = 5
local renderY = 212
local spectralMinimum = 5



--Save/Load Data
--For reasons I can't understand this causes an error
--However, everything seems to work fine without this
function stackable_stew:saveData()
    local table = { numStews, damages, time, renderX, renderY }
    stackable_stew:SaveData(stackable_stew, json.encode(table))
end

stackable_stew:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, stackable_stew.saveData)

function stackable_stew:loadData()
    if stackable_stew:HasData() then
        local data = json.decode(Isaac.LoadModData(stackable_stew))
        numStews = data[1]
        damages = data[2]
        time = data[3]
        renderX = data[4]
        renderY = data[5]
        spectralMinimum = data[6]
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, stackable_stew.loadData)



function stackable_stew:Update()
    --RESET VALUES HERE
    if Game():GetFrameCount() == 1 then
        numStews = 0 --sets numStews to 0 at the start of the run
        damages = {}
        time = 0
    end

    --When the player picks up a stew item
    if (Game():GetPlayer(0):GetCollectibleNum(stackable_stew.STEW_ITEM_ID) > numStews) then
        numStews = numStews + 1
        --Add the new stew damage to the damages array
        table.insert(damages, 21.6)
        --Edit player stats
        player = Game():GetPlayer(0)
        player:SetFullHearts()
        --player.Damage = player.Damage + 21.6
        --Add player costume
        player:AddNullCostume(Isaac.GetCostumeIdByPath("gfx/characters/stackable_stew.anm2"))
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_UPDATE, stackable_stew.Update)



--This handles the damage reduction over time per stew
function stackable_stew:UpdateDamages()
    --Every time 1 second of game time has passed
    if math.floor(Game().TimeCounter / 30) > time then
        time = time + 1
        --Find initial sum of damages
        damage_initial = 0
        for i in ipairs(damages) do damage_initial = damage_initial + damages[i] end

        --Tick down the stew damages every in-game second
        for i in ipairs(damages) do
            damages[i] = damages[i] - 0.12
            --remove damage boost if it is expired
            if damages[i] <= 0 then table.remove(damages, i) end
        end

        --Find final sum of damages
        damage_final = 0
        for i in ipairs(damages) do damage_final = damage_final + damages[i] end

        --Remove difference of damage from the player's stat
        delta_damage = math.abs(damage_final - damage_initial)
        --Game():GetPlayer(0).Damage = Game():GetPlayer(0).Damage - delta_damage
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, stackable_stew.UpdateDamages)



--This handles applying and removing the tear effects
function stackable_stew:SetTearEffects()
    if #damages ~= 0 then
        --Get damage to add to unboosted tears
        damageBoost = 0
        for i in ipairs(damages) do damageBoost = damageBoost + damages[i] end

        for i, entity in pairs(Isaac.GetRoomEntities()) do
            --Use this to change tear properties
            local Tear = entity:ToTear()

            --Change tear costume if it is the default costume
            if (entity.Type == EntityType.ENTITY_TEAR) and (entity.Variant == TearVariant.BLUE) then
                Tear:ChangeVariant(TearVariant.BLOOD)
            end

            --Add damage boost to tear if it has not already been boosted
            if (entity.Type == EntityType.ENTITY_TEAR) and (type(entity:GetData()["HasStewDamageBoost"]) == type(nil)) then
                --Add damage boost
                Tear.CollisionDamage = Tear.CollisionDamage + damageBoost

                --Add spectral and piercing effect if you reach the minimum required stews
                if (#damages >= spectralMinimum) then Tear.TearFlags = Tear.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING end

                --Change tear size (currently not working)
                Tear:SetSize(Tear.Size + damageBoost / 21.6, Tear.SizeMulti + Vector(damageBoost / 21.6, damageBoost / 21.6), 0)
                Tear.Scale = Tear.Scale + damageBoost / 21.6

                --Flag tear as having damage changed
                entity:GetData()["HasStewDamageBoost"] = true
            end
        end
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, stackable_stew.SetTearEffects)



--Every time an enemy is killed, boost the temporary damages by 0.04
--This mimmicks the 'Lusty Blood' effect of the stew
function stackable_stew:BoostDamages()
    player = Game():GetPlayer(0)
    for i in ipairs(damages) do
        --player.Damage = player.Damage + 0.04
        damages[i] = damages[i] + 0.04
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, stackable_stew.BoostDamages)



--This function takes the damages table and outputs its values to the console (used for debugging)
--Code 'borrowed' from https://stackoverflow.com/questions/7274380/how-do-i-display-array-elements-in-lua
function array_to_string(arr, indentLevel)
    local str = ""
    local indentStr = "#"

    if (indentLevel == nil) then
        return array_to_string(arr, 0)
    end

    for i = 0, indentLevel do
        indentStr = indentStr .. "\t"
    end

    for index, value in pairs(arr) do
        if type(value) == "table" then
            str = str .. indentStr .. index .. ": \n" .. array_to_string(value, (indentLevel + 1))
        else
            str = str .. "#" .. index .. ": " .. value .. "\n"
        end
    end
    return str
end

--To render the actual damage output of the player's tears
function stackable_stew:RenderDamageStats()
    if #damages ~= 0 then
        --Set up font
        local f = Font()
        f:Load("font/terminus.fnt")
        --Draw Title
        f:DrawStringScaled("Stew Buffs", renderX, renderY, 0.5, 0.5, KColor(1, 1, 1, 1), 0, true)
        --Draw Individual Boosts & calculate total damage
        totalDMG = 0 + Game():GetPlayer(0).Damage
        for i in ipairs(damages) do
            totalDMG = totalDMG + damages[i]
            f:DrawStringScaled("#" .. i .. ": " .. damages[i], renderX, renderY + 10 * i, 0.5, 0.5, KColor(1, 1, 1, 1), 0, true)
        end
        --Draw damage sum
        f:DrawStringScaled("Total Damage: " .. string.format("%.2f", totalDMG), renderX, renderY + 10 + 10 * #damages,
            0.5, 0.5, KColor(1, 1, 1, 1), 0, true)
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_RENDER, stackable_stew.RenderDamageStats)



--To edit the position of the HUD element
function stackable_stew:UpdateUIPos()
    if (#damages ~= 0) and (Input.IsButtonPressed(Keyboard.KEY_COMMA, 0)) then
        if Input.IsButtonPressed(Keyboard.KEY_RIGHT, 0) then
            renderX = renderX + 1
        elseif Input.IsButtonPressed(Keyboard.KEY_LEFT, 0) then
            renderX = renderX - 1
        elseif Input.IsButtonPressed(Keyboard.KEY_UP, 0) then
            renderY = renderY - 1
        elseif Input.IsButtonPressed(Keyboard.KEY_DOWN, 0) then
            renderY = renderY + 1
        end
    end
end

stackable_stew:AddCallback(ModCallbacks.MC_POST_UPDATE, stackable_stew.UpdateUIPos)