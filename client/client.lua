Cooldowns = {}
Contracts = {}
Profile = {}
Blips = {}
Leaderboard = false
inQueue = false
gotPoliceCount = false

-- In contract variables
currentContract = false
carBlip = false
deliveryBlip = false
notDelivered = true

-- Receiving player Data
RegisterNetEvent('joni_boosting:client:receivePlayerData', function(pendingContracts, playerData)
    playerData.xpPerLevel = 100
    playerData.class = calculateProfileClass(playerData.xp)
    Profile = playerData
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='receivePlayerData', playerData=playerData})
    for i=1, #pendingContracts do
        pendingContracts[i].imgSrc = Config.ImageCDN .. pendingContracts[i].vehicle .. '.png'
        pendingContracts[i].carName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(pendingContracts[i].vehicle)))
    end
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='refreshContracts', Contracts=pendingContracts})
end)

RegisterNetEvent('joni_boosting:client:recvContract', function(contract)
    local contractData = contract
    -- Appending non-trivial data at last to avoid increasing event size.
    contractData['imgSrc'] = Config.ImageCDN .. contractData.vehicle .. '.png'
    contractData['carName'] = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(contractData.vehicle)))
    table.insert(Contracts, contractData)
    --if Config.DebugMode then print("[RECV Contract] pushing recv contract to NUI, " .. #Contracts .. " ready to do.") end
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='refreshContracts', Contracts=Contracts})
end)

RegisterNetEvent('joni_boosting:client:updateLobby', function(lobbyData)
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='updateLobby', lobby=lobbyData})
end)

RegisterNetEvent('joni_boosting:client:destroyLobby', function(showError)
    if showError then
        exports['joni_tablet']:sendNotification('NAVSTAR', 'Vuestro contrato se ha cancelado por causas ajenas a la organización', 10000, 'error')
    end
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='destroyLobby'})
end)

RegisterNetEvent('joni_boosting:client:destroyContract', function()
    ClearGpsPlayerWaypoint()
    if carBlip then
        RemoveBlip(carBlip)
        carBlip = false
    end
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = false
    end
    exports['timer']:stopTimer()
    currentContract = false
end)

RegisterNetEvent('joni_boosting:client:tryLobby', function(reason)
    Wait(4000) -- Wait is because the response is way too fast in order to show that the tablet is real attempt trying
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {action='lobbyMessage', message=reason})
end)

RegisterNetEvent('joni_boosting:client:contractStarted', function(contractData, owned)
    exports['joni_tablet']:sendNotification('NAVSTAR', 'Hemos iniciado la misión para usted, cúmplala', '2500', 'info')
    currentContract = contractData
    StartContract(contractData, owned)
end)

RegisterNetEvent('joni_boosting:client:vehicleContract', function(vehEntity)
    while true do
        if (NetworkDoesEntityExistWithNetworkId(vehEntity)) then
            currentContract.vehEntity = NetworkGetEntityFromNetworkId(vehEntity)
            return
        end
    Wait(100)
    end
end)

RegisterNetEvent('joni_boosting:client:vehicleHotwire', function()
    currentContract.isVehLockpicked = true
    RemoveBlip(carBlip)
    exports['timer']:stopTimer()
    if currentContract.hacksRequired > 0 then
        Citizen.CreateThread(function()
            onVehicleHotwired(currentContract)
        end)
    end
end)

RegisterNetEvent('joni_boosting:client:receivePoliceCount', function(PoliceCount)
    Wait(1000)
    gotPoliceCount:resolve(PoliceCount)
end)

RegisterNetEvent('joni_boosting:client:boostingLocUpdate', function(contractId, plate, carModel, position)
    local carName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(carModel)))
    if (not position) then
        RemoveBlip(Blips[contractId].blipHandler)
        Blips[contractId] = nil
        return
    end

    if not Blips[contractId] then
        Blips[contractId] = {
            position = position,
            blipHandler = AddBlipForCoord(position)
        }
    else
        RemoveBlip(Blips[contractId].blipHandler)
        Blips[contractId].blipHandler = AddBlipForCoord(position)
        Blips[contractId].position = position
    end
    BeginTextCommandSetBlipName("STRING")
    local blipText = carName .. ' [' .. plate .. ']'
    AddTextComponentString(blipText)
    EndTextCommandSetBlipName(Blips[contractId].blipHandler)
    SetBlipSprite(Blips[contractId].blipHandler, Config.Blips.trackerBlip.sprite)
    SetBlipScale(Blips[contractId].blipHandler, Config.Blips.trackerBlip.scale)
    SetBlipColour(Blips[contractId].blipHandler, Config.Blips.trackerBlip.color)
end)

RegisterNetEvent('joni_boosting:client:attemptHack', function(class, attemptingAlready, isCooldown)
    if (attemptingAlready == false and isCooldown == false) then
        Citizen.CreateThread(function()
            attemptVehicleHack(class)
        end)
    else
        if attemptingAlready and isCoolodown then
            return
        end
        if attemptingAlready then
            ShowNotification('Ya hay alguien intentado hackear el coche')
        else
            ShowNotification('Todavía no puedes hackear el vehículo')
        end
    end
end)

RegisterNetEvent('joni_boosting:client:hackingComplete', function(class)
    print("Hacking completed!")

    Citizen.CreateThread(function()
        -- Set Blip
        local deliveryBlip = AddBlipForCoord(vec3(currentContract.deliveryCoords.x, currentContract.deliveryCoords.y, currentContract.deliveryCoords.z))
        SetBlipSprite(deliveryBlip, Config.Blips.deliveryBlip.sprite)
        SetBlipColour(deliveryBlip, Config.Blips.deliveryBlip.color)
        SetBlipScale(deliveryBlip, Config.Blips.deliveryBlip.scale)
        if (Config.Blips.deliveryBlip.setWaypoint) then
            SetBlipRoute(deliveryBlip, true)
            SetBlipRouteColour(deliveryBlip, 3)
        end
        -- Deliver thread
        local deliverCoords = currentContract.deliveryCoords
        local notified = false
        while notDelivered do
            local playerPed = PlayerPedId()
            local isPlayerInVehicle = IsPedInAnyVehicle(playerPed, false)
            if (isPlayerInVehicle) then
                playerVehicle = GetVehiclePedIsIn(playerPed, false)
            else
                playerVehicle = false
            end
            local playerCoords = GetEntityCoords(playerPed)
            local dx = playerCoords.x - deliverCoords.x
            local dy = playerCoords.y - deliverCoords.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if playerVehicle then
                vehPlate = GetVehicleNumberPlateText(playerVehicle)
            end

            print(vehPlate, currentContract.plate)
            
            if ((distance < 22.5 and vehPlate == currentContract.plate) and (not notified)) then
                print("Close to finish", notified, plaverVehicle, distance)
                notified = true
                exports['timer']:changeText('Abandona el vehículo en este área y vete a casa, recibirás tu recompensa más adelante.')
            end

            if (notified and playerVehicle == false and distance > 22.5) then
                print("Finishing contract", notified, plaverVehicle, distance)
                notDelivered = true
                RemoveBlip(deliveryBlip)
                ClearAllBlipRoutes()
                TriggerServerEvent('joni_boosting:server:contractFinished', currentContract.contractId)
                exports['timer']:stopTimer()
                exports['joni_tablet']:sendNotification('NAVSTAR', 'Misión completada con éxito, buen trabajo.', 5000, 'success')
                return
            end
            Wait(1000)
        end
    end)
    Citizen.CreateThread(function()
        onVehicleSuccessfullyHacked(class)
    end)
end)

RegisterNetEvent('joni_boosting:client:policeBlip', function(contractId)
    if Blips and Blips[contractId] then
        RemoveBlip(Blips[contractId].blipHandler)
        Blips[contractId] = nil
    end
end)

RegisterNetEvent('joni_boosting:client:receiveLeaderboard', function(leaderboard)
    Leaderboard = leaderboard
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {leaderboard=leaderboard})
end)

RegisterNetEvent('joni_boosting:client:shop:boughtItem', function()
    exports['joni_tablet']:sendNotification('Compra de artículo', 'Tu compra se ha procesado correctamente.', 2500, 'success')
end)

----------------------------------------
---             FUNCTIONS            ---
----------------------------------------
function calculateProfileClass(xp)
    local highestLevel = -1000
    local level = xp / 100
    for k,v in pairs(Config.Classes) do
        if (v.minLevelRequired <= level) and (highestLevel <= v.minLevelRequired) then
            highestLevel = v.minLevelRequired
            class = k
        end
    end
    return class, level
end

function InitCooldowns()    
    local level = Profile.xp / 100
    for k,v in pairs(Config.Classes) do
        if v.minLevelRequired <= level then
            Cooldowns[k] = math.random(v.cooldown.min, v.cooldown.max)
            --if Config.DebugMode then print('[Init Cooldown] Class ' .. k .. ' will have ' .. Cooldowns[k]/1000 .. ' seconds cooldown') end
        end
        -- Didn't meet criteria for receiving those contracts.
    end
end

function CooldownThread()
    while inQueue do
        if #Contracts > Config.Contracts.maxAmount then
            -- if Config.DebugMode then print("[Cooldown Thread] Stopped the contract generation thread due to maximum amount of contracts being active.") end
            ToggleQueue(false)
        end

        -- 1000msec per iteration
        for k,v in pairs(Cooldowns) do
            Cooldowns[k] = tonumber(v - 1000)
            -- Contract is 0 seconds or negative, generate contract
            if Cooldowns[k] <= 0 then
                GetContract(k)
                ResetCooldown(k)
                -- if Config.DebugMode then print("[Cooldown Thread] Cooldown reset for " .. k) end
            end
        end
        Wait(1000)
    end
end

function ResetCooldown(class)
    Cooldowns[class] = math.random(Config.Classes[class].cooldown.min, Config.Classes[class].cooldown.max)
    if Config.DebugMode then
        -- print('[Reset Cooldown] Class ' .. class .. ' will have ' .. Cooldowns[class]/1000 .. ' seconds cooldown')
    end
end

function ToggleQueue(state)
    inQueue = state
    if state == true then
        if #Contracts > Config.Contracts.maxAmount then
            inQueue = false
            --if Config.DebugMode then print("[TQ] This player already has the maximum amount of contracts (general)") end
            return false
        end
        CreateThread(function()
            InitCooldowns()
            CooldownThread()
        end)
    end
end

function GetContract(class)
    local chance = math.random(0, 100)
    local generated = false

    if chance <= Config.Classes[class].chance then
        TriggerServerEvent('joni_boosting:server:reqContract', class)
        generated = true
    end

    if Config.DebugMode then
        if generated then
            --print('[Get Contract] Send to server to generate a new class on ' .. class .. ' we rolled ' .. chance .. ' and we needed less/equal than ' .. Config.Classes[class].chance)
        else
            --print('[Get Contract] Attempted to generate a new contract on class ' .. class .. ' but we rolled ' .. chance .. ' and we needed less/equal than ' .. Config.Classes[class].chance)
        end
    end
end

if Config.DebugMode then
    local opened = false
    RegisterCommand('boosting', function()
        opened = not opened
        SendNUIMessage({ action = 'toggleVisibility' })
        SetNuiFocus(opened, opened)
    end)
end

function StartContract(contractData, owned)
    Phase1FindVehicle(contractData, owned)
end

function Phase1FindVehicle(contractData, owned)
    VehicleNotClose = true
    --if Config.DebugMode then print('[Phase1FindVehicle] Starting contract!') end
    Citizen.CreateThread(function()
        onContractStarted(contractData)
    end)

    -- Set Blip
    local randomXOffset = math.random(-Config.Classes[contractData.class].maximumAreaOffset, Config.Classes[contractData.class].maximumAreaOffset)
    local randomYOffset = math.random(-Config.Classes[contractData.class].maximumAreaOffset, Config.Classes[contractData.class].maximumAreaOffset)
    carBlip = AddBlipForRadius(vec3(contractData.carCoords.x + randomXOffset, contractData.carCoords.y + randomYOffset, contractData.carCoords.z), Config.Classes[contractData.class].areaRadius)
    SetBlipColour(carBlip, Config.Blips.areaBlip.color)
    SetBlipAlpha(carBlip, Config.Blips.areaBlip.opacity)
    
    if (owned) then
        -- Thread to Spawn Vehicle
        Citizen.CreateThread(function()
            random = math.random(0,100)
            while VehicleNotClose do
                local playerCoords = GetEntityCoords(PlayerPedId())
                if (#(vec3(contractData.carCoords.x, contractData.carCoords.y, contractData.carCoords.z) - playerCoords) < Config.SetVehicleDataDist) then
                    if Config.DebugMode then print('[Phase1FindVehicle] Creating the vehicle!') end
                    local vehHash = GetHashKey(contractData.vehicle)
                    RequestModel(vehHash)
                    while not HasModelLoaded(vehHash) do
                        Wait(50)
                    end
                    if HasModelLoaded(vehHash) then
                        while not HasModelLoaded(vehHash) do Wait(5) end
                        local veh = CreateVehicle(vehHash, contractData.carCoords.x, contractData.carCoords.y, contractData.carCoords.z, contractData.carCoords.h, true, true)
                        SetEntityAsMissionEntity(veh, true, true)
                        while not DoesEntityExist(veh) do
                            Wait(100)
                        end
                        SetVehicleNumberPlateText(veh, contractData.plate)
                        SetVehicleDoorsLocked(veh, 10)
                        SetVehicleColours(veh, contractData.primaryColor.index, contractData.secondaryColor.index)
                        if Config.Classes[contractData.class].mods.chance > random then
                            for i=1, #Config.Classes[contractData.class].mods.nums do
                                SetVehicleMod(veh, Config.Classes[contractData.class].mods.nums[i])
                            end
                        end
                        Citizen.CreateThread(function()
                            onBoostingVehicleSpawn(veh)
                        end)
                        Wait(500) -- give some extra time to server
                        TriggerServerEvent('joni_boosting:server:vehicleContract', contractData.contractId, NetworkGetNetworkIdFromEntity(veh))
                        if Config.DebugMode then print('[Phase1FindVehicle] Vehicle has spawned at coords:' .. vec3(contractData.carCoords.x, contractData.carCoords.y, contractData.carCoords.z)) end
                        VehicleNotClose = false
                    else
                        print("INFORMACION DE DEPURACION, EL VEHICULO NO HA CARGADO!")
                    end
                end
                Wait(2000)
            end
        end)
    end
end

function lockPickVehicle()
    if (currentContract) then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local vehicles = GetVehiclesInArea(playerCoords, 25.0)
        local foundTargetVehicle = false
        for _, vehicle in ipairs(vehicles) do
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(vehicleCoords - playerCoords)

            if distance < Config.LockpickDist then
                local plate = GetVehicleNumberPlateText(vehicle)
                if plate == currentContract.plate then
                    foundTargetVehicle = true
                    Citizen.CreateThread(function()
                        onLockPickAttempt(vehicle)
                    end)
                    break
                end
            end
        end
        if not foundTargetVehicle then
            ShowNotification('No se encontró el vehículo!')
        end
    else
        ShowNotification('No estás en un contrato!')
    end
end

-- Helper function to get vehicles in a certain radius
function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(vehicleCoords - coords)

        if distance <= radius then
            table.insert(vehicles, vehicle)
        end

        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    
    return vehicles
end

exports('lockPickVehicle', lockPickVehicle)

function requestVehicleHack()
    if (currentContract) then
        if (currentContract.vehEntity and currentContract.isVehLockpicked) then
            local playerPed = PlayerPedId()
            local veh = GetVehiclePedIsIn(playerPed, false)
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate == currentContract.plate then
                TriggerServerEvent('joni_boosting:server:attemptHack', currentContract.contractId)
            else
                ShowNotification('Este no es el vehículo que tienes que hackear o debes estar dentro.')
            end
        end
    else
        ShowNotification('No tienes ningún vehículo que hackear')
    end
end
exports('requestVehicleHack', requestVehicleHack)

function loadShopData()
    exports['joni_tablet']:sendEvent(GetCurrentResourceName(), {shopData=Config.Shop})
end

----------------------------------------
---             CALLBACKS            ---
----------------------------------------

-- On First Open of the APP request user-data/leaderboard-data
RegisterNUICallback('onFirstAppOpen', function(_, cb)
    TriggerServerEvent('joni_boosting:server:requestPlayerData')
    TriggerServerEvent('joni_boosting:server:requestLeaderboard')
    loadShopData()
    cb(1)
end)

-- On APP no longer being present (no item, w/e)
RegisterNUICallback('onAppRemove', function()
    -- SendNUIMessage({ action = 'toggleVisibility' })
end)

RegisterNUICallback('queueStatus', function(data, cb)
    --if Config.DebugMode then print("[CB] Queue Status:", data.inQueue) end
    ToggleQueue(data.inQueue)
    cb(data.inQueue)
end)

RegisterNUICallback('destroyContract', function(recvContract, cb)
    -- Destroy contract on server-side 
    TriggerServerEvent('joni_boosting:server:destroyContract', recvContract.contractId)
    -- Destroy contract on client-side
    for i=1, #Contracts do
        if Contracts[i].contractId == recvContract.contractId then
            --if Config.DebugMode then print('[NUI destroyContract], found the contract. Destroying it') end
            table.remove(Contracts, i)
            currentContract = false
            Citizen.CreateThread(function()
                onContractDestroy(recvContract)            
            end)
            cb(1)
            break
        end
    end
end)

RegisterNUICallback('contractAccepted', function(contractId, cb)
    TriggerServerEvent('joni_boosting:server:contractAccepted', contractId.contractId)
    cb(1)
end)

RegisterNUICallback('contractStarted', function(contractId, cb)
    TriggerServerEvent('joni_boosting:server:contractStarted', contractId.contractId)
    cb(1)
end)

RegisterNUICallback('joinLobby', function(data, cb)
    -- if Config.DebugMode then print('[joinLobby] Trying to join lobby ' .. data.contractId .. ' as player ' .. data.playerName) end
    TriggerServerEvent('joni_boosting:server:joinContract', data)
    cb(1)
end)

RegisterNUICallback('changeProfileName', function(profileName, cb)
    if (profileName.playerName) then
        TriggerServerEvent('joni_boosting:server:changeProfileData', 'profileName', profileName.playerName)
    end
    cb(1)
end)

RegisterNUICallback('changeProfilePic', function(profilePic, cb)
    if (profilePic.playerPicture) then
        TriggerServerEvent('joni_boosting:server:changeProfileData', 'profilePic', profilePic.playerPicture)
    end
    cb(1)
end)

RegisterNUICallback('toggleQueue', function(data, cb)
    local state = data.state
    ToggleQueue(state)
    cb(1)
end)

RegisterNUICallback('fetchPoliceCount', function(data, cb)
    exports['joni_tablet']:sendNotification('NAVSTAR', 'Estamos revisando tu petición...', 1000, 'info')
    gotPoliceCount = promise.new()
    TriggerServerEvent('joni_boosting:server:getPoliceCount')
    local response = Citizen.Await(gotPoliceCount)
    gotPoliceCount = false
    Wait(850)
    cb({
        policeCount=response, 
        policeNeeded=Config.Classes[data.class].policeNeeded
    })
end)

RegisterNUICallback('buyItem', function(data, cb)
    print("Buying Item", data.itemPackage)
    local checkEconomy = promise.new()
    TriggerServerEvent('joni_boosting:server:shop:checkAvailability', data.itemPackage)
    Citizen.Await(checkEconomy)
    cb(1)
end)