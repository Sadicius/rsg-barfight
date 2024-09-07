local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterServerEvent('rsg-core:server:StartSaloonFight')
AddEventHandler('rsg-core:server:StartSaloonFight', function(playerId, location, radius)
    
    local user = RSGCore.Functions.GetPlayer(playerId)
    if user then
        local character = user.PlayerData
        local firstName = character.charinfo.firstname
        local lastName = character.charinfo.lastname
        local steamHex = GetPlayerIdentifier(playerId, 0)

        -- Generate random positions for peds
        local pedPositions = GetRandomPositionsAroundPoint(location.x, location.y, location.z, Config.AngryPeds.spawnRadius, Config.AngryPeds.number)
        
        -- Notify all players about the fight
        TriggerEvent('rNotify:NotifyLeft', "BAR FIGHT", "STARTED", "generic_textures", "tick", 4000)
		
        
        -- Radius Check and trigger events for players
        local players = GetPlayersInRadius(location, radius)
        for _, player in ipairs(players) do
            --TriggerClientEvent('showFightMessage', player, Config.FightNotification)
            TriggerClientEvent('applyFightRestrictions', player, Config.FightRestrictionDuration)
            TriggerClientEvent('spawnAngryPeds', player, pedPositions, Config.AngryPeds.models, Config.AngryPeds.despawnTime)
        end

        -- Discord Webhook
        local webhookMessage = string.format(Config.DiscordWebhook.wmessage, firstName, lastName, steamHex)
        TriggerDiscordWebhook(webhookMessage)
    else
        
    end
end)




function GetRandomPositionsAroundPoint(centerX, centerY, centerZ, radius, count)
    local positions = {}
    for i = 1, count do
        local angle = math.random() * 2 * math.pi
        local r = math.sqrt(math.random()) * radius
        local x = centerX + r * math.cos(angle)
        local y = centerY + r * math.sin(angle)
        table.insert(positions, {x = x, y = y, z = centerZ})
    end
    return positions
end

function GetPlayersInRadius(location, radius)
    local playersInRadius = {}
    for _, playerId in ipairs(GetPlayers()) do
        local playerPed = GetPlayerPed(playerId)
        local playerPos = GetEntityCoords(playerPed)
        if GetDistanceBetweenCoords(playerPos, location) < radius then
            table.insert(playersInRadius, playerId)
        end
    end
    return playersInRadius
end

function GetDistanceBetweenCoords(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function TriggerDiscordWebhook(message)
    PerformHttpRequest(Config.DiscordWebhook.url, function(err, text, headers) end, 'POST', json.encode({content = message}), { ['Content-Type'] = 'application/json' })
end