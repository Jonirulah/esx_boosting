if Config.Framework ~= 'esx' then return end

ESX = exports["es_extended"]:getSharedObject()

TriggerCallback = ESX.TriggerServerCallback

function ShowNotification(text)
    ESX.ShowNotification(text)
end

function GetIdentifier()
    return ESX.PlayerData.identifier
end

function GetName()
    return ('%s %s'):format(ESX?.PlayerData?.firstName, ESX?.PlayerData?.lastName)
end

function GetJob()
    return ESX.PlayerData.job.name
end

function GetGrade()
    return ESX.PlayerData.job.grade
end

function GetGradeLabel()
    return ESX.PlayerData.job.grade_label
end

CreateThread(function()
    repeat Wait(2000) until ESX and ESX.PlayerData and ESX.PlayerData.job
    frameworkLoaded = true
end)