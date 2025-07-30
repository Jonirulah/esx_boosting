-- Exposed Functions to allow other implementations out of the script
exports['joni_tablet']:registerAppData(Config.Tablet)
AddEventHandler('onResourceStart', function(resName)
    if resName == 'joni_tablet' then
        exports['joni_tablet']:registerAppData(Config.Tablet)

    end
end)

RegisterNetEvent('joni_boosting:server:removeLockPick', function()
    local playerId = source
    exports.ox_inventory:RemoveItem(playerId, 'boosting_lockpick', 1)
end)

-- Function when the user scratched a vehicle
function VinScratched(vehEntity)

end

-- Server-side function when a user accepted a contract
function onContractAccepted(contractData)

end

-- Server-side function when a user started a contract
function onContractStarted(contractData)

end

-- Function when the vehicle gets lockpicked
function VehicleLockPicked(vehEntity)

end

function giveReward(playerId, contractData, shouldSplit, memberCount)
    if (shouldSplit == true and memberCount) then
        exports.ox_inventory:AddItem(playerId, 'money', math.floor(contractData.moneyReward / memberCount))
    else
        exports.ox_inventory:AddItem(playerId, 'money', contractData.moneyReward)
    end
end

function fetchPoliceIds()
    return exports.osx_duty:getDutyPlayers(Config.PoliceJobs)
end

function fetchPoliceCount()
    return #exports.osx_duty:getDutyPlayers(Config.PoliceJobs)
end

-- When user success at buying an item
function onSuccessBuyItem(playerId, item, count)
    print(playerId, item, count)
    exports.ox_inventory:AddItem(playerId, item, count)
end