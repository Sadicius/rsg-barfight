local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedPeds = {}

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, ped in ipairs(spawnedPeds) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
        -- Clear the list after deletion
        spawnedPeds = {}
    end
end)


RegisterNetEvent('spawnAngryPeds')
AddEventHandler('spawnAngryPeds', function(pedPositions, pedModels, despawnTime)
    Citizen.CreateThread(function()
        for i, position in ipairs(pedPositions) do
            local modelName = pedModels[math.random(#pedModels)]
            local modelHash = GetHashKey(modelName)

            
            RequestModel(modelHash)
            local timeout = GetGameTimer() + 5000  
            while not HasModelLoaded(modelHash) do
                Citizen.Wait(10) 
                if GetGameTimer() > timeout then
                    break
                end
            end

            
            if HasModelLoaded(modelHash) then
               
                local ped = CreatePed(modelHash, position.x, position.y, position.z, 0.0, true, false)
                
                if DoesEntityExist(ped) then
                    
                    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)

                    
                    RemoveAllPedWeapons(ped, true)

                    
                    SetBlockingOfNonTemporaryEvents(ped, true)

                    
                    TaskCombatPed(ped, PlayerPedId(), 0, 16)

                    -- Despawn after the specified time
                    Citizen.SetTimeout(despawnTime, function()
                        if DoesEntityExist(ped) then
                            DeleteEntity(ped)
                        end
                    end)
                end
            end
        end
    end)
end)





function ShowFightMessage()
    ClearPedTasks(PlayerPedId())
    
    RSGCore.Functions.Notify(Config.FightNotification.message, 'info', Config.FightNotification.duration)
end

local isTriggered = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        
        if IsControlJustReleased(0, 0xD8F73058) and IsControlPressed(0, 0xF84FA74F) then
            isTriggered = true
        end

        if isTriggered and IsPedShooting(PlayerPedId()) then
            CheckForFire()
        end
    end
end)

function CheckForFire()
    for _, fightLocation in ipairs(Config.FightLocations) do
        local playerPos = GetEntityCoords(PlayerPedId())
        local location = fightLocation.location
        local radius = fightLocation.radius

        if Vdist(playerPos.x, playerPos.y, playerPos.z, location.x, location.y, location.z) < radius then
            
            TriggerServerEvent('rsg-core:server:StartSaloonFight', GetPlayerServerId(PlayerId()), location, radius)
			
        end
    end

    isTriggered = false
end

RegisterNetEvent('showFightMessage')
AddEventHandler('showFightMessage', function()
    ShowFightMessage()
end)

local function MakeNearbyPedsFlee()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local radius = 20.0 -- Adjust this to change the area where peds will flee

    -- Get all peds in the area
    local peds = GetGamePool('CPed')
    for _, ped in ipairs(peds) do
        if ped ~= playerPed and not IsPedAPlayer(ped) then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - pedCoords)
            
            if distance <= radius then
                -- Make the ped flee
                TaskSmartFleePed(ped, playerPed, 100.0, -1, true, true)
                SetPedKeepTask(ped, true)
            end
        end
    end
end

RegisterNetEvent('applyFightRestrictions')
AddEventHandler('applyFightRestrictions', function()
    local RESTRICTION_END_TIME = GetGameTimer() + Config.FightRestrictionDuration
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    -- Notify the player about the fight restrictions
    TriggerEvent('rNotify:NotifyLeft', "FIREARMS DISABLED", "BAR FIGHT", "generic_textures", "tick", 4000)
    Wait(5000)
    TriggerEvent('rNotify:NotifyLeft', "FISTS ONLY BRAWL BEGUN", "BAR FIGHT", "generic_textures", "tick", 4000)
    
    -- Alert lawmen about the bar fight
    TriggerServerEvent('rsg-lawman:server:lawmanAlert', "Bar fight in progress!", playerCoords)
    
    CreateThread(function()
        while GetGameTimer() <= RESTRICTION_END_TIME do
            Citizen.Wait(0)
            local ped = PlayerPedId()
            
            -- Disable firing for all weapons
            SetPedConfigFlag(ped, 58, true)
            SetPedConfigFlag(ped, 60, true)
            
            -- Disable weapon wheel and weapon-related controls
            DisableControlAction(0, 0xD8F73058, true) -- Weapon Wheel
            DisableControlAction(0, 0x4CC0E2FE, true) -- Weapon Wheel Up/Down
            DisableControlAction(0, 0x07CE1E61, true) -- LMB (Fire)
            DisableControlAction(0, 0xF84FA74F, true) -- RMB (Aim)
            DisableControlAction(0, 0x0AF99998, true) -- R key (Reload)
            DisableControlAction(0, 0x8B7ECFB7, true) -- Equip/Unequip Weapon
            
            -- Allow melee controls
            EnableControlAction(0, 0x2EAB0795, true) -- Melee Attack Light
            EnableControlAction(0, 0x0283C582, true) -- Melee Attack Heavy
            EnableControlAction(0, 0xB2F377E8, true) -- Melee Block
        end
        
        -- Re-enable weapon functionality for the player
        local ped = PlayerPedId()
        SetPedConfigFlag(ped, 58, false)
        SetPedConfigFlag(ped, 60, false)
        
        -- Make nearby NPCs flee
        MakeNearbyPedsFlee()
        
        -- Notify the player that the fight is over
        TriggerEvent('rNotify:NotifyLeft', "FIGHT OVER - NPCs FLEEING!", "BAR FIGHT", "generic_textures", "tick", 4000)
        
        -- Wait for a few seconds while the NPCs are running
        Wait(5000)
        
        -- Notify the player that the area is clear
        TriggerEvent('rNotify:NotifyLeft', "BAR FIGHT CONCLUDED", "AREA CLEAR", "generic_textures", "tick", 4000)
        
        -- Alert lawmen that the fight has ended
        TriggerServerEvent('rsg-lawman:server:lawmanAlert', "Bar fight has ended.", playerCoords)
    end)
end)


