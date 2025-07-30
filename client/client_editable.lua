function onBoostingVehicleSpawn(vehicle)
    if Config.DebugMode then print('[onBoostingVehicleSpawn] Set vehicle hotwired!') end
    exports['osx_vehicles']:setVehicleHotwired(vehicle)
    Entity(vehicle).state.fuel = 65
end

function onContractStarted(contractData)
    -- Start clock timer
    Citizen.CreateThread(function()
        -- This timer doesnt return the value until it has ended or we stop it (think about it as a callback)
        local stopReason = exports['timer']:startTimer(Config.Classes[contractData.class].time.findVehicle, 'Encuentra y roba el vehículo <b>' .. GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(contractData.vehicle))) .. '</b> de color <b> ' .. contractData.primaryColor.label .. ' </b>con matrícula <b>' .. contractData.plate .. '</b>')
        if stopReason == 'timerEnded' then
            TriggerServerEvent('joni_boosting:server:destroyContract', contractData.contractId)
        end
    end)
end

function onContractEnded()

end

function onContractDestroy(contractData)
    -- This will hide the timer from the UI
    if exports['timer']:isTimerActive() then
        exports['timer']:stopTimer()
    end
end

function attemptVehicleHack(class)
    local settings = {
        gridSize = math.random(Config.Classes[class].hack.grid.min, Config.Classes[class].hack.grid.max), 
        required = Config.Classes[class].hack.required,
        timeLimit = Config.Classes[class].hack.timeLimit,
        charSet = Config.Classes[class].hack.charset[math.random(1, #Config.Classes[class].hack.charset)]
    }
    exports["glow_minigames"]:StartMinigame(function(success)
        TriggerServerEvent('joni_boosting:server:hackResult', currentContract.contractId, success)
    end, "spot", settings)
end
exports('attemptVehicleHack', attemptVehicleHack)

function onVehicleSuccessfullyHacked(class)
    exports['timer']:stopTimer()
    local stopReason = exports['timer']:startTimer(Config.Classes[class].time.deliverVehicle, 'Entrega el vehículo y recibe tu recompensa')
    if stopReason == 'timerEnded' then
        TriggerServerEvent('joni_boosting:server:destroyContract', contractData.contractId)
    end
end

function onVehicleHotwired(contractData)
    Citizen.CreateThread(function()
        local stopReason = exports['timer']:startTimer(Config.Classes[contractData.class].time.hackVehicle, 'Completa el hackeo del vehículo')
        if stopReason == 'timerEnded' then
            TriggerServerEvent('joni_boosting:server:destroyContract', contractData.contractId)
        end
    end)
end

function onLockPickAttempt()
    if (not currentContract.isVehLockpicked) then
        local success = exports["t3_lockpick"]:startLockpick(Config.Classes[currentContract.class].lockPickDifficulty.strength, Config.Classes[currentContract.class].lockPickDifficulty.difficulty, Config.Classes[currentContract.class].lockPickDifficulty.pins)
        if success == true then
            TriggerServerEvent('joni_boosting:server:vehicleHotwire', currentContract.contractId)
            notifyPolice(currentContract)
            unlockVehicle(currentContract.vehEntity)
            -- Remove lockpick success chance
            chance = math.random(0,100)
            if (chance <= Config.LockpickRemoveChance.success) then
                TriggerServerEvent('joni_boosting:server:removeLockPick')
            end
        elseif success == false then
            if Config.Classes[currentContract.class].lockPickDifficulty.notifyPoliceOnFail then
                notifyPolice(currentContract)
            end
            -- Remove lockpick fail chance
            chance = math.random(0,100)
            if (chance <= Config.LockpickRemoveChance.fail) then
                TriggerServerEvent('joni_boosting:server:removeLockPick')
            end
        end
    else
        ShowNotification('Este vehículo ya ha sido forzado!')
    end
end

local function RGBToHex(r, g, b)
    local function componentToHex(c)
        local hex = string.format('%02X', c)
        return hex
    end
    local hex = '#' .. componentToHex(r) .. componentToHex(g) .. componentToHex(b)
    return hex
end

function notifyPolice(contractData)
    local pState = LocalPlayer.state
    local Vehicle = currentContract.vehEntity
    local vehCoords = GetEntityCoords(Vehicle)
    prio = "low"
    if (contractData.hacksRequired > 0) then
        if (contractData.class == "A" or contractData.class == "S") then
            text = '[' .. pState.uid .. ']-B Están robando el vehículo de un VIP del gobierno, es un vehículo de alto valor es un %s con matrícula %s de color %s. ¡Tiene un rastreador GPS!'
            prio = 'medium'
        else
            text = '[' .. pState.uid .. ']-B Están robando un %s con matrícula %s de color %s. ¡Tiene un rastreador GPS!'
            prio = 'medium'
        end
    else
        text = '[' .. pState.uid .. ']-B Están robando un %s con matrícula %s de color %s. ¡Vengan rapido por favor!'
        prio = 'low'
    end
    local model = GetEntityModel(Vehicle)
    local model_string = GetDisplayNameFromVehicleModel(model)
    local model_form = model_string:sub(1, 1):upper() .. model_string:sub(2):lower()
    local plate = GetVehicleNumberPlateText(Vehicle)
    local r, g, b = GetVehicleColor(Vehicle)
    text = string.format(text, model_form, plate, '/' .. RGBToHex(r, g, b) .. [[\]])
    local data = {
        code = '37',
        default_priority = prio,
        coords = vehCoords,
        job = { 'police', 'sheriff' },
        text = text,
        type = 'car_robbery',
        custom_sound = 'https://cdn.pixabay.com/audio/2024/08/23/audio_4297cdf5af.mp3',
        blip = {
            sprite = 56,
            colour = 1,
            scale = 0.7,
        }
    }
    TriggerServerEvent('rcore_dispatch:server:sendAlert', data)    
end

function unlockVehicle(veh)
    SetVehicleDoorsLocked(veh, 1)
    TriggerServerEvent('joni_boosting:server:vehicleHotwire', currentContract.contractId)
end
