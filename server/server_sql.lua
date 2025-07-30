SQL = {}

function SQL.GetPlayerData(identifier)
    local response = MySQL.prepare.await('SELECT * FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    if Config.DebugMode then print('[SQL.GetPlayerData] Fetching player', identifier) end

    if response then
        return response
    end
    local playerData = SQL.CreatePlayer(identifier)
    return playerData
end

function SQL.CreatePlayer(identifier)
    local response = MySQL.prepare.await('INSERT INTO `boosting_players` (`identifier`) VALUES (?)', {identifier})
    if Config.DebugMode then print('[SQL.CreatePlayer] Inserting new player', identifier) end
    local newPlayer = SQL.GetPlayerData(identifier)
    return newPlayer
end

function SQL.GetBoostingPlayerPicture(identifier)
    local response = MySQL.prepare.await('SELECT `profile_picture` FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    return response
end

function SQL.GetBoostingPlayerName(identifier)
    local response = MySQL.prepare.await('SELECT `profile_name` FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    return response
end

function SQL.GetBoostingXP(identifier)
    local response = MySQL.prepare.await('SELECT `xp` FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    return response
end

function SQL.GetBoostingCredits(identifier)
    local response = MySQL.prepare.await('SELECT `credits` FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    return response
end

function SQL.GetBoostingReputation(identifier)
    local response = MySQL.prepare.await('SELECT `reputation` FROM `boosting_players` WHERE `identifier` = ?', {identifier})
    return response
end

function SQL.UpdatePlayerName(identifier, name)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `profile_name` = ? WHERE `identifier` = ?', {name, identifier})
    return response
end

function SQL.UpdatePlayerPicture(identifier, picture)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `profile_picture` = ? WHERE `identifier` = ?', {picture, identifier})
    return response
end

function SQL.UpdatePlayerProfile(identifier, xpReward, creditReward, repReward)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `xp` = `xp` + ?, `credits` = `credits` + ?, `reputation` = `reputation` + ? WHERE `identifier` = ?', {xpReward, creditReward, repReward, identifier})
    return response
end

function SQL.RemoveBoostingCredits(identifier, creditsToRemove)
    local credits = SQL.GetBoostingCredits(identifier)
    if (credits - creditsToRemove) < 0 then
        return false
    else
        local response = MySQL.prepare.await('UPDATE `boosting_players` SET `credits` = `credits` - ? WHERE `identifier` = ? AND `credits` >= ?', {creditsToRemove, identifier, creditsToRemove})
        return true
    end 
end

function SQL.AddBoostingXP(identifier, xpToAdd)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `xp` = `xp` + ? WHERE `identifier` = ?', {xpToAdd, identifier})
    return response
end

-- Add Credits to Player's Existing Credits
function SQL.AddBoostingCredits(identifier, creditsToAdd)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `credits` = `credits` + ? WHERE `identifier` = ?', {creditsToAdd, identifier})
    return response
end

-- Add Reputation to Player's Existing Reputation
function SQL.AddBoostingReputation(identifier, reputationToAdd)
    local response = MySQL.prepare.await('UPDATE `boosting_players` SET `reputation` = `reputation` + ? WHERE `identifier` = ?', {reputationToAdd, identifier})
    return response
end

function SQL.InsertBoostingRecord(contractId, identifier, xpReward, moneyReward, creditReward, repReward)
    if Config.DebugMode then print('[SQL.InsertBoostingRecord] Inserting new boosting record') end
    local response = MySQL.prepare.await('INSERT INTO `boosting_contracts` (`contractId`, `playerIdentifier`, `xpReward`, `moneyReward`, `creditReward`, `repReward`, `date`) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)', {contractId, identifier, xpReward, moneyReward, creditReward, repReward})
    return response
end

function SQL.GetLeaderBoard()
    local response = MySQL.prepare.await("SELECT p.profile_name, p.profile_picture, p.xp AS profileXP, p.reputation, COUNT(c.id) AS totalContracts FROM boosting_contracts c JOIN boosting_players p ON c.playerIdentifier = p.identifier GROUP BY c.playerIdentifier, p.xp ORDER BY p.reputation DESC LIMIT 30;")
    return response
end

-- Fetch functions in next version

exports('updatePlayerProfile', SQL.UpdatePlayerProfile)
exports('addBoostingCredits', SQL.AddBoostingCredits)
exports('addBoostingReputation', SQL.AddBoostingReputation)
exports('addBoostingXP', SQL.AddBoostingXP)
exports('getBoostingPlayerName', SQL.GetBoostingPlayerName)
exports('getBoostingPlayerPicture', SQL.GetBoostingPlayerPicture)
exports('getBoostingXP', SQL.GetBoostingXP)
exports('getBoostingCredits', SQL.GetBoostingCredits)
exports('getBoostingReputation', SQL.GetBoostingReputation)
