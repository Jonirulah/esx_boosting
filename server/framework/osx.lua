if Config.Framework ~= 'esx' then return end

ESX = exports["es_extended"]:getSharedObject()

RegisterCallback = ESX.RegisterServerCallback
CreateUsableItem = ESX.RegisterUsableItem

function ShowNotification(src, text, notifyType)
    TriggerClientEvent('osx:showNotification', src, text)
end

--- Get the player from the source
--- @param playerId number
function GetPlayerFromId(playerId)
    return ESX.GetPlayerFromId(playerId)
end

function GetPlayerFromIdentifier(identifier)
    return ESX.GetPlayerFromIdentifier(identifier)
end

function GetSource(xPlayer)
    return xPlayer.source
end

function GetIdentifier(xPlayer)
    return xPlayer.identifier
end

function GetName(xPlayer)
    return xPlayer.getName()
end

function GetPlayers()
    return ESX.GetPlayers()
end

function GetJob(xPlayer)
    return xPlayer?.job
end

function GetJobName(xPlayer)
    return xPlayer?.job?.name
end

function GetGrade(xPlayer)
    return xPlayer?.job?.grade
end

function SetJob(xPlayer, job, grade)
    xPlayer.setJob(job, grade)
end

function GetAccountMoney(xPlayer, account)
    return xPlayer.getAccount(account).money
end

function AddAccountMoney(xPlayer, account, amount)
    xPlayer.addAccountMoney(account, amount)
end

function RemoveAccountMoney(xPlayer, account, amount)
    xPlayer.removeAccountMoney(account, amount)
end

function GetItemAmount(xPlayer, item)
    return xPlayer.getInventoryItem(item)?.count or 0
end

function GetItemLabel(item)
    return ESX.GetItemLabel(item) or item
end

RegisterCallback('tk_boosting:getItemLabel', function(src, cb, item)
	cb(GetItemLabel(item))
end)

CreateThread(function()
    repeat Wait(100) until ESX

    frameworkLoaded = true
end)