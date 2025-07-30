Server = {}
Server.Players = {}
Server.ActiveContracts = {}
Server.PoliceCount = 0
Server.PoliceTable = {}
Server.Leaderboard = {}
Server.Shop = {}

Citizen.CreateThread(function()
    counter = 0
    Server.Leaderboard = GenerateLeaderboard()
    while true do
        Server.PoliceCount = fetchPoliceCount()
        Server.PoliceTable = fetchPoliceIds()
        print("Actual police count active is " .. Server.PoliceCount)
        Wait(60000) -- every 60 seconds
        -- Get leaderboard every
        counter = counter + 1
        if counter >= 60 then
            counter = 0
            Citizen.CreateThread(function()
                Server.Leaderboard = GenerateLeaderboard()
                TriggerLatentClientEvent('joni_boosting:client:receiveLeaderboard', -1, 48000, Server.Leaderboard)
            end)
        end
    end
end)

----------------------------------------
---             FUNCTIONS            ---
----------------------------------------
function GenerateLeaderboard()
    leaderboard = SQL.GetLeaderBoard()
    return leaderboard
end

function GenerateContract(class)
    local carCoords = Config.VehCoords[math.random(1, #Config.VehCoords)]
    local contractCFG = Config.Classes[class]
    local contractData = {
        class=class,
        --expire=math.random(contractCFG.time.contract.min, contractCFG.time.contract.max),
        contractId=GenerateShortId(),
        contractCost=math.random(contractCFG.costPrice.min, contractCFG.costPrice.max),
        xp=math.random(contractCFG.reward.xp.min, contractCFG.reward.xp.max),
        vehicle=Config.Vehicles[class][math.random(1, #Config.Vehicles[class])],
        plate=GenerateRandomPlate(),
        creditReward=math.random(contractCFG.reward.credits.min, contractCFG.reward.credits.max),
        moneyReward=math.random(contractCFG.reward.money.min, contractCFG.reward.money.max),
        repReward=math.random(contractCFG.reputation.min, contractCFG.reputation.max),
        carCoords=carCoords,
        deliveryCoords=FindRandomVec4ByDistance(Config.DeliveryCoords, carCoords, 500),
        hacksRequired=math.random(contractCFG.hack.needed.min, contractCFG.hack.needed.max),
        hackCooldown=contractCFG.hack.cooldown,
        primaryColor = Config.Colors[math.random(1, #Config.Colors)],
        secondaryColor = Config.Colors[math.random(1, #Config.Colors)]
    }
    return contractData
end

function destroyLobbyForAllPlayers(contractId, showError, origin)
    if Server.ActiveContracts[contractId] then
        for i=1, #Server.ActiveContracts[contractId]['members'] do
            TriggerClientEvent('joni_boosting:client:destroyLobby', Server.ActiveContracts[contractId]['members'][i].playerId, showError)
        end
    end
    if Config.DebugMode then print("[destroyLobbyForAllPlayers] Sending all clients in the contract " .. contractId .. " to destroy the lobby UI", origin) end
end

function destroyContractForAllPlayers(contractId)
    local contract = Server.ActiveContracts[contractId]
    for i=1, #Server.ActiveContracts[contractId]['members'] do
        TriggerClientEvent('joni_boosting:client:destroyContract', Server.ActiveContracts[contractId]['members'][i].playerId)
    end
    Server.ActiveContracts[contractId] = nil
end

function updateLobbyForAllPlayers(contractId)
    if Server.ActiveContracts[contractId] then
        for i=1, #Server.ActiveContracts[contractId]['members'] do
            TriggerClientEvent('joni_boosting:client:updateLobby', Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId])
            if Config.DebugMode then print("[updateLobbyForAllPlayers] updating lobby for tempId:" .. Server.ActiveContracts[contractId]['members'][i].playerId .. " contract " .. contractId) end

        end
    end
    if Config.DebugMode then print("[updateLobbyForAllPlayers] Sending all clients in the contract " .. contractId .. " to update the lobby UI") end
end

function startPoliceTracking(contractId)
    while ((Server.ActiveContracts[contractId].hacksDone < Server.ActiveContracts[contractId].contractData.hacksRequired) and Server.ActiveContracts[contractId]) do
        if Config.DebugMode then print("[startPoliceTracking] The vehicle in contract " .. contractId .. " has been lockpicked and it is under police tracking!") end
        for i=1, #Server.PoliceTable do
            if (Server.ActiveContracts[contractId].networkId) then
                local entity = NetworkGetEntityFromNetworkId(Server.ActiveContracts[contractId].networkId)
                carCoords = GetEntityCoords(entity)
            else
                if Config.DebugMode then print('[startPoliceTracking], Network ID is not existing for contract ' .. contractId)
                end
            end
            TriggerClientEvent('joni_boosting:client:boostingLocUpdate', Server.PoliceTable[i], contractId, Server.ActiveContracts[contractId].contractData.plate, Server.ActiveContracts[contractId].contractData.vehicle, carCoords)
        end
        Wait(Server.ActiveContracts[contractId].blipInterval)
    end
end

function hackCooldown(contractId, cooldown)
    Wait(cooldown * 1000)
    Server.ActiveContracts[contractId].isHackCooldown = false
end

function removeVehicle(vehHandler)
    local entity = NetworkGetEntityFromNetworkId(vehHandler)
    FreezeEntityPosition(entity, true)
    Wait(5000)
    DeleteEntity(entity)
end

function updateProfileData(playerId)
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    local playerData = SQL.GetPlayerData(playerIdentifier)
    if playerIdentifier then
        local contracts = Server.Players[playerIdentifier] and Server.Players[playerIdentifier]['contracts'] or {}
        TriggerClientEvent('joni_boosting:client:receivePlayerData', playerId, contracts, playerData)
    end
end

function removeContractForOwner(identifier, contractId)
    if Server.Players[identifier]['contracts'] then
        for i=1, #Server.Players[identifier]['contracts'] do
            if Server.Players[identifier]['contracts'][i].contractId == contractId then
                table.remove(Server.Players[identifier]['contracts'], i)
                print("Found contract for player " .. identifier .. " removing contract " .. contractId)
                break
            end
        end
    end
end

function hasEnoughLevel(xp, class)
    local highestLevel = -1000
    local level = xp / 100
    local levelRequired = Config.Classes[class].minLevelRequired
    if level >= levelRequired then
        return true
    end
    return false
end

----------------------------------------
---              EVENTS              ---
----------------------------------------

RegisterNetEvent('joni_boosting:server:reqContract', function(class)
    local playerId = source 
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    local playerName = SQL.GetBoostingPlayerName(playerIdentifier)
    local playerXP = SQL.GetBoostingXP(playerIdentifier)
    if (hasEnoughLevel(playerXP, class)) then
        if Config.DebugMode then print('[Contract Generator] Player has enough level to request this contract class:' .. class) end
        -- Check for player cached data
        if not Server.Players[playerIdentifier] then
            Server.Players[playerIdentifier] = {}
            for k,v in pairs(Config.Classes) do
                Server.Players[playerIdentifier][k] = 0
            end
            if Config.DebugMode then print('[Contract Generator] Player requested a contract, he was not cached, creating it!') end
        else
            -- Return when we exceeded the limit, no further processing
            if (Server.Players[playerIdentifier][class] >= Config.Classes[class].maxContractsPerRestart) then
                if Config.DebugMode then print('[Contract Generator] Attempted to generate a contract for ' .. playerIdentifier .. ' however he already did ' .. Config.Classes[class].maxContractsPerRestart .. ' contracts from class ' .. class) end
                return
            end
        end
        -- Player doesnt have contracts
        if not Server.Players[playerIdentifier]['contracts'] then Server.Players[playerIdentifier]['contracts'] = {} end

        -- Player already has a contract
        if #Server.Players[playerIdentifier]['contracts'] >= Config.Contracts.maxAmount then
            --if Config.DebugMode then print('[Contract Generator] Player ' .. playerIdentifier .. ' has the maximum amount of contracts! Cant generate more due to Config.Contracts.maxAmount being ' .. Config.Contracts.maxAmount) end
            return
        else
            -- Inserting the contract into playerData!
            if Config.DebugMode then print('[Contract Generator] Generated a contract for ' .. playerIdentifier .. ' he already did ' .. Server.Players[playerIdentifier][class] .. '/' .. Config.Classes[class].maxContractsPerRestart .. ' contracts from class ' .. class) end
            local generatedContract = GenerateContract(class)
            if generatedContract then
                Server.Players[playerIdentifier][class] = Server.Players[playerIdentifier][class] + 1
                table.insert(Server.Players[playerIdentifier]['contracts'], generatedContract)
                TriggerClientEvent('joni_boosting:client:recvContract', playerId, generatedContract)
            else
                print('[Contract Generator] Failed to generate a contract for ' .. playerIdentifier .. ' due to an error in the contract generation process.')
            end
        end
    else
        if Config.DebugMode then print('[Contract Generator - Possible Cheating?] Player doesnt enough level to request this contract') end
    end
end)

-- Event when the contract gets accepted by the owner.
RegisterNetEvent('joni_boosting:server:contractAccepted', function(contractId)
    local playerId = source
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    local playerName = SQL.GetBoostingPlayerName(playerIdentifier)

    -- Security Check!
    for i=1, #Server.Players[playerIdentifier]['contracts'] do 
        if Server.Players[playerIdentifier]['contracts'][i].contractId == contractId then
            -- Withdraw player credits and update their UI
            local successRemove = SQL.RemoveBoostingCredits(playerIdentifier, Server.Players[playerIdentifier]['contracts'][i].contractCost)
            if successRemove then
                if Config.DebugMode then print('[joni_boosting:server:contractAccepted] Player ' .. playerIdentifier .. ' has accepted the contract ' .. contractId) end
                Server.ActiveContracts[contractId] = {members = {{playerId = playerId, owner=true, playerName = playerName, playerIdentifier = playerIdentifier}}, started=false, contractData=Server.Players[playerIdentifier]['contracts'][i]}
                return
            else
                if Config.DebugMode then print('[joni_boosting:server:contractAccepted] Player ' .. playerIdentifier .. ' has accepted the contract ' .. contractId .. ' but he didnt had credits!') end
                destroyLobbyForAllPlayers(contractId, true, "destroy-accepted")
                destroyContractForAllPlayers(contractId)
                return
            end
        end
    end
    if Config.DebugMode then print('[joni_boosting:server:contractAccepted] Player ' .. playerIdentifier .. ' attempted to accept the contract  ' .. contractId .. ' but he didnt had it!') end
    Citizen.CreateThread(function()
        onContractAccepted(Server.ActiveContracts[contractId])
    end)
end)

-- Event when the contract actually starts (play button) WIP
RegisterNetEvent('joni_boosting:server:contractStarted', function(contractId)
    local playerId = source
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    if Server.ActiveContracts[contractId] then
        if playerId == Server.ActiveContracts[contractId]['members'][1].playerId then
            if Config.DebugMode then print('[joni_boosting:server:contractStarted] Player ' .. playerIdentifier .. ' has started the contract ' .. contractId) end
            Server.ActiveContracts[contractId].started = true
        else return end
        -- Send event to all lobby members
        for i=1, #Server.ActiveContracts[contractId]['members'] do
            if Config.DebugMode then print('[joni_boosting:server:contractStarted] Player ' .. playerIdentifier .. ' were in the lobby so they started the contract ' .. contractId) end
            TriggerClientEvent('joni_boosting:client:contractStarted', Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId].contractData, Server.ActiveContracts[contractId]['members'][i].owner)
        end
        Citizen.CreateThread(function()
            onContractStarted(Server.ActiveContracts[contractId])
        end)
    else
        if Config.DebugMode then print('[joni_boosting:server:contractStarted] Player ' .. playerIdentifier .. ' attempted to start a contract ' .. contractId .. ' that wasnt even accepted!') end
    end
end)

-- Event for when players want to join a contract.
RegisterNetEvent('joni_boosting:server:joinContract', function(data)
    local playerId = source
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    -- Check if contract was started
    if not Server.ActiveContracts[data.contractId] then
        TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'notexist')
        return 
    end
    -- Check if we can join this contract
    if (Config.CanJoinHigherContracts == true) then
        if Server.ActiveContracts[data.contractId].started then
            if Config.DebugMode then print('[joni_boosting:server:joinContract] Player with tempId:' .. playerId .. ' is trying to join the contract, however this contract ' .. data.contractId .. ' has started!') end
            TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'started')
            return
        end 
        -- Check if contract is full
        if #Server.ActiveContracts[data.contractId]['members'] >= Config.MaxGroupMembers then
            if Config.DebugMode then print('[joni_boosting:server:joinContract] Player with tempId:' .. playerId .. ' is trying to join the contract, however this contract ' .. data.contractId .. ' is full!') end
            TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'full')
            return
        end
        -- Check if member is already part of the contract
        for i=1, #Server.ActiveContracts[data.contractId]['members'] do
            if playerId == Server.ActiveContracts[data.contractId]['members'][i].playerId then
                if Config.DebugMode then print('[joni_boosting:server:joinContract] Player with tempId:' .. playerId .. ' was already in the contract ' .. data.contractId .. ' so he didnt join!') end
                TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'own')
                return
            end
        end
    else
        local playerLevel = SQL.GetBoostingXP(playerIdentifier) / 100
        local contractLevel = Config.Classes[Server.ActiveContracts[data.contractId].contractData.class].minLevelRequired
        if playerLevel < contractLevel then
            TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'notlevel')
            if Config.DebugMode then print('[joni_boosting:server:joinContract] Player with tempId:' .. playerId .. ' didnt had enough level to join ' .. data.contractId .. ' so he didnt join!') end
            return 
        end
    end

    if Config.DebugMode then print('[joni_boosting:server:joinContract] Player with tempId:' .. playerId .. ' has joined the contract ' .. data.contractId) end
    table.insert(Server.ActiveContracts[data.contractId]['members'], {playerId = playerId, owner=false, playerName = data.playerName, playerIdentifier = playerIdentifier})
    TriggerClientEvent('joni_boosting:client:tryLobby', playerId, 'joined')
    updateLobbyForAllPlayers(data.contractId)
end)

RegisterNetEvent('joni_boosting:server:destroyContract', function(contractId)
    local playerId = source
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    if Server.ActiveContracts[contractId] then
        for i=1, #Server.ActiveContracts[contractId]['members'] do
            if Server.ActiveContracts[contractId]['members'][i].playerIdentifier == playerIdentifier then
                if Config.DebugMode then print('[joni_boosting:server:destroyContract] Contract existing, destroying.') end
                destroyLobbyForAllPlayers(contractId, true, "destroy-normal")
                if (Server.ActiveContracts[contractId]?.started) then
                    destroyContractForAllPlayers(contractId)
                    Server.ActiveContracts[contractId] = nil
                end
                removeContractForOwner(playerIdentifier, contractId)
                break
            else
                if Config.DebugMode then print('[joni_boosting:server:destroyContract] Client sent to destroy contract but not existing...') end
            end
        end
    end
end)

function sendPlayerData(playerId)
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    local playerData = SQL.GetPlayerData(playerIdentifier)
    if playerIdentifier then
        local contracts = Server.Players[playerIdentifier] and Server.Players[playerIdentifier]['contracts'] or {}
        TriggerClientEvent('joni_boosting:client:receivePlayerData', playerId, contracts, playerData)
    end

end
RegisterNetEvent('joni_boosting:server:requestPlayerData', function()
    local playerId = source
    sendPlayerData(playerId)
end)

RegisterNetEvent('joni_boosting:server:changeProfileData', function(field, data)
    local playerId = source
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    if Config.DebugMode then print('[joni_boosting:server:changeProfileData] Received request to change profile data field:' .. field .. ' data:' .. data) end
    if (field == 'profilePic') then
        SQL.UpdatePlayerPicture(playerIdentifier, data)
        local playerData = SQL.GetPlayerData(playerIdentifier)
        TriggerClientEvent('joni_boosting:client:receivePlayerData', playerId, Server.Players[playerIdentifier] and Server.Players[playerIdentifier]['contracts'] or {}, playerData)
    elseif (field == 'profileName') then
        SQL.UpdatePlayerName(playerIdentifier, data)
        local playerData = SQL.GetPlayerData(playerIdentifier)
        TriggerClientEvent('joni_boosting:client:receivePlayerData', playerId, Server.Players[playerIdentifier] and Server.Players[playerIdentifier]['contracts'] or {}, playerData)
    end
end)

RegisterNetEvent('joni_boosting:server:vehicleContract', function(contractId, networkEntity)
    local playerId = source 
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    for i=1, #Server.Players[playerIdentifier]['contracts'] do
        if Server.Players[playerIdentifier]['contracts'][i].contractId == contractId then
            if Config.DebugMode then print('[joni_boosting:server:vehicleContract] Player ' .. playerIdentifier .. ' has spawned the vehicle for ' .. contractId) end
            local networkId = networkEntity
            Server.ActiveContracts[contractId].networkId = networkId
            for ix=1, #Server.ActiveContracts[contractId]['members'] do
                TriggerClientEvent('joni_boosting:client:vehicleContract', Server.ActiveContracts[contractId]['members'][ix].playerId, networkId)
                if Config.DebugMode then print('[joni_boosting:server:vehicleContract] Sent vehicle entity handler to ' ..  Server.ActiveContracts[contractId]['members'][ix].playerId) end
            end
        end
    end
end)

RegisterNetEvent('joni_boosting:server:vehicleHotwire', function(contractId)
    local playerId = source 
    local playerIdentifier = GetPlayerFromId(playerId)?.identifier
    if Server.ActiveContracts[contractId] and (not Server.ActiveContracts[contractId].hotwire) then
        Server.ActiveContracts[contractId].hotwire = true
        Server.ActiveContracts[contractId].hacksDone = 0
        Server.ActiveContracts[contractId].attemptHack = false
        Server.ActiveContracts[contractId].isHackCooldown = false
        Server.ActiveContracts[contractId].requestedEnd = false
        Server.ActiveContracts[contractId].blipInterval = Config.Classes[Server.ActiveContracts[contractId].contractData.class].alert.interval

        local chance = math.random(0,100)
        if (chance < Config.Classes[Server.ActiveContracts[contractId].contractData.class].alert.chance) then
            -- Police Tracking Thread
            Citizen.CreateThread(function()
                startPoliceTracking(contractId)
            end)            
        end


        for i=1, #Server.ActiveContracts[contractId]['members'] do
            TriggerClientEvent('joni_boosting:client:vehicleHotwire', Server.ActiveContracts[contractId]['members'][i].playerId)
            if (Server.ActiveContracts[contractId].contractData.hacksRequired == 0) then
                TriggerClientEvent('joni_boosting:client:hackingComplete', Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId].contractData.class)
            end
            if Config.DebugMode then print('[joni_boosting:server:vehicleHotwire] Sent vehicle entity handler to ' ..  Server.ActiveContracts[contractId]['members'][i].playerId) end
        end
    end
end)

RegisterNetEvent('joni_boosting:server:getPoliceCount', function()
    local playerId = source
    TriggerClientEvent('joni_boosting:client:receivePoliceCount', playerId, Server.PoliceCount)
end)

-- Pending HACK IMPL
RegisterNetEvent('joni_boosting:server:attemptHack', function(contractId)
    local playerId = source
    if Config.DebugMode then print('[joni_boosting:server:attemptHack] Client is attempting to hack for contract ' .. contractId) end
    if (Server.ActiveContracts[contractId].hacksDone >= Server.ActiveContracts[contractId].contractData.hacksRequired) then
        TriggerClientEvent('joni_boosting:client:attemptHack', playerId, Server.ActiveContracts[contractId].contractData.class, true, true)
        Server.ActiveContracts[contractId].isHackCooldown = true
        if Config.DebugMode then print('[joni_boosting:server:attemptHack] Contract is already done of hacks') end
    end
    if ((Server.ActiveContracts[contractId].attemptHack or Server.ActiveContracts[contractId].isHackCooldown)) then
        TriggerClientEvent('joni_boosting:client:attemptHack', playerId, Server.ActiveContracts[contractId].contractData.class, Server.ActiveContracts[contractId].attemptHack, Server.ActiveContracts[contractId].isHackCooldown)
            if Config.DebugMode then print('[joni_boosting:server:attemptHack] Hack is in cooldown') end
        else
        TriggerClientEvent('joni_boosting:client:attemptHack', playerId, Server.ActiveContracts[contractId].contractData.class, Server.ActiveContracts[contractId].attemptHack, Server.ActiveContracts[contractId].isHackCooldown)
        if Config.DebugMode then print('[joni_boosting:server:attemptHack] User started hacking game') end
        Server.ActiveContracts[contractId].attemptHack = true
        Server.ActiveContracts[contractId].isHackCooldown = true
        hackCooldown(contractId, Server.ActiveContracts[contractId].contractData.hackCooldown)
    end
end)

RegisterNetEvent('joni_boosting:server:hackResult', function(contractId, result)
    if Server.ActiveContracts[contractId] then
        if (result == true) then
            Server.ActiveContracts[contractId].hacksDone = Server.ActiveContracts[contractId].hacksDone + 1
            Server.ActiveContracts[contractId].blipInterval = Server.ActiveContracts[contractId].blipInterval + Config.Classes[Server.ActiveContracts[contractId].contractData.class].alert.timeAdd
            if Config.DebugMode then print('[joni_boosting:server:attemptHack] Hacked for contract ' .. contractId .. ' | '.. Server.ActiveContracts[contractId].hacksDone .. '/' .. Server.ActiveContracts[contractId].contractData.hacksRequired .. ' Blip Interval:' .. Server.ActiveContracts[contractId].blipInterval .. 's') end
            if Server.ActiveContracts[contractId].hacksDone >= Server.ActiveContracts[contractId].contractData.hacksRequired then
                print("All hacks has been done!")
                TriggerClientEvent('joni_boosting:client:policeBlip', -1, contractId)
                Citizen.CreateThread(function()
                    for i=1, #Server.ActiveContracts[contractId]['members'] do
                        TriggerClientEvent('joni_boosting:client:hackingComplete', Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId].contractData.class)
                    end
                end)
            end
        end
        Server.ActiveContracts[contractId].attemptHack = false
    end
end)

RegisterNetEvent('joni_boosting:server:contractFinished', function(contractId)
    local playerId = source
    -- Check if contract with ID exists
    if Server.ActiveContracts[contractId] and (not Server.ActiveContracts[contractId].requestedEnd) then
        Server.ActiveContracts[contractId].requestedEnd = true
        -- Check if variables made during the process do exist.
        if Server.ActiveContracts[contractId].networkId then
            for i=1, #Server.ActiveContracts[contractId]['members'] do
                -- Check if member is from same contract
                if Server.ActiveContracts[contractId]['members'][i].playerId == playerId then
                    if Config.DebugMode then print('[joni_boosting:server:contractFinished] Player id:' .. playerId .. ' has request to end the contract, ending') end
                    SQL.InsertBoostingRecord(Server.ActiveContracts[contractId].contractData.contractId, Server.ActiveContracts[contractId]['members'][i].playerIdentifier, Server.ActiveContracts[contractId].contractData.xp, Server.ActiveContracts[contractId].contractData.moneyReward, Server.ActiveContracts[contractId].contractData.creditReward, Server.ActiveContracts[contractId].contractData.repReward)
                    updateProfileData(playerId)
                    Citizen.CreateThread(function()
                        removeVehicle(Server.ActiveContracts[contractId].networkId)
                    end)
                    Wait(1000)
                end

                if (Config.Classes[Server.ActiveContracts[contractId].contractData.class].reward.splitReward == true) then
                    local members = #Server.ActiveContracts[contractId]['members']
                    local xp = math.floor(Server.ActiveContracts[contractId].contractData.xp / members)
                    local credit = math.floor(Server.ActiveContracts[contractId].contractData.creditReward / members)
                    local reputation = math.floor(Server.ActiveContracts[contractId].contractData.repReward / members)
                    SQL.UpdatePlayerProfile(Server.ActiveContracts[contractId]['members'][i].playerIdentifier, xp, credit, reputation)
                    giveReward(Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId].contractData, true, members)
                    print("Giving contract reward to (split)", Server.ActiveContracts[contractId]['members'][i].owner, Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId]['members'][i].playerIdentifier)
                else
                    if (Server.ActiveContracts[contractId]['members'][i].owner == true) then
                        SQL.UpdatePlayerProfile(Server.ActiveContracts[contractId]['members'][i].playerIdentifier, Server.ActiveContracts[contractId].contractData.xp, Server.ActiveContracts[contractId].contractData.creditReward, Server.ActiveContracts[contractId].contractData.repReward)
                        giveReward(Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId].contractData, false)
                        print("Giving contract reward to (full)", Server.ActiveContracts[contractId]['members'][i].owner, Server.ActiveContracts[contractId]['members'][i].playerId, Server.ActiveContracts[contractId]['members'][i].playerIdentifier)
                    end
                end

                if (Server.ActiveContracts[contractId]['members'][i].owner == true) then
                    removeContractForOwner(Server.ActiveContracts[contractId]['members'][i].playerIdentifier, contractId)
                end
                sendPlayerData(Server.ActiveContracts[contractId]['members'][i].playerId)
            end
            destroyLobbyForAllPlayers(contractId, false)
            destroyContractForAllPlayers(contractId)
            -- Send player updated data on contract end
        else
            if Config.DebugMode then print('[joni_boosting:server:contractFinished] A player id:' .. playerId .. ' has requested to end the contract ' .. contractId .. ' however the contract didnt had the vehicle spawned') end
        end
    end
end)

RegisterNetEvent('joni_boosting:server:requestLeaderboard', function()
    local playerId = source
    TriggerClientEvent('joni_boosting:client:receiveLeaderboard', playerId, Server.Leaderboard)
end)

function canBuy(player, playerId, item)
    local canBuy = false
    for i=1, #Config.Shop do
        if (Config.Shop[i].item_name == item) and (Config.Shop[i].item_buyLimitPerRestart >= Server.Shop[player.identifier][item].qtyBought + 1) then
            itemShop = Config.Shop[i]
            canBuy = true
            break
        end
    end
    if (canBuy) then
        local money = GetAccountMoney(player, 'money')
        local credits = SQL.GetBoostingCredits(player.identifier)
        if (money > itemShop.item_moneyPrice) and (credits >= itemShop.item_creditPrice) then
            RemoveAccountMoney(player, 'money', itemShop.item_moneyPrice)
            SQL.RemoveBoostingCredits(player.identifier, itemShop.item_creditPrice)
            Server.Shop[player.identifier][item].qtyBought = Server.Shop[player.identifier][item].qtyBought + 1
            sendPlayerData(playerId)
            CreateThread(function()
                onSuccessBuyItem(playerId, item, itemShop.item_quantity)
            end)
            Wait(2000)
            TriggerClientEvent('joni_boosting:client:shop:boughtItem', playerId)
        end
    end
end

RegisterNetEvent('joni_boosting:server:shop:checkAvailability', function(item)
    local playerId = source
    local player = GetPlayerFromId(playerId)
    -- Check if user has bought previously.
    if Server.Shop[player.identifier] then
    else Server.Shop[player.identifier] = {} end
    -- Check for data
    if Server.Shop[player.identifier][item] then
        canBuy(player, playerId, item)
    else 
        Server.Shop[player.identifier][item] = {qtyBought = 0}
        canBuy(player, playerId, item)
    end
    --local result = checkShopAvailability()
end)

-- Tests pending
-- ADD CHECK IF PLAYER DROPPED AND HE WAS IN CONTRACT CLEAN ENVIRONMENT
RegisterNetEvent('playerDropped', function(playerId)
    for key, data in pairs(Server.ActiveContracts) do
        -- Check for 1 player doing contract and he crashes
        if data.members then
            for _, memberData in pairs(data.members) do
                if #Server.ActiveContracts[data.contractData.contractId].members == 1 and memberData.playerId == playerId and memberData.owner == true then
                    destroyLobbyForAllPlayers(data.contractData.contractId, true, "destroy-dropped")
                    destroyContractForAllPlayers(contdata.contractData.contractId)
                    Server.ActiveContracts[data.contractData.contractId] = nil            
                end
            end
        end
        -- Check if player disconnected from a multiplayer session (he owned it) and the vehicle never spawned.
        if not data.networkId then
            if data.members then
                for _, memberData in pairs(data.members) do
                    if memberData.playerId == playerId and memberData.owner == true then
                        print("Player has disconnected from the server! He was doing the contract but not vehicle was spawned yet by his side (not close to location), deleting contract")
                        destroyLobbyForAllPlayers(data.contractData.contractId, true, "destroy-dropped")
                        destroyContractForAllPlayers(data.contractData.contractId)
                        Server.ActiveContracts[contractId] = nil
                        return
                    end
                end
            end
        else
        -- A member has disconnected from the contract, reset attemptHack in case he was hacking.
            if data.members then
                for _, memberData in pairs(data.members) do
                    if memberData.playerId == playerId then
                        print("Player has disconnected from the server! He was doing the contract, fixing/resetting potential bugs caused.")
                        Server.ActiveContracts[data.contractData.contractId].attemptHack = false
                        return
                    end
                end
            end
        end
    end
end)
