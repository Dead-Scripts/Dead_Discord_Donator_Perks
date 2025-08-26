-------------------------------------
--- DiscordDonatorPerks by Dead ---
-------------------------------------

-- CONFIG
roleList = Config.RoleList
ESX = nil
QBCore = nil

if Config.Use_ESX then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
else
    QBCore = exports['qb-core']:GetCoreObject()
end

-- PERK QUEUE
perkQueue = {}
hasPerkAccess = {}

-- UTILITY FUNCTIONS
function ExtractIdentifiers(src)
    local identifiers = {steam="", ip="", discord="", license="", xbl="", live=""}
    for i = 0, GetNumPlayerIdentifiers(src)-1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "steam") then identifiers.steam = id
        elseif string.find(id, "ip") then identifiers.ip = id
        elseif string.find(id, "discord") then identifiers.discord = id
        elseif string.find(id, "license") then identifiers.license = id
        elseif string.find(id, "xbl") then identifiers.xbl = id
        elseif string.find(id, "live") then identifiers.live = id
        end
    end
    return identifiers
end

function setPlayerJob(src, jobName, jobGrade)
    if Config.Use_QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(src)
        qbPlayer.SetJob(jobName, jobGrade)
    else
        local xPlayer = ESX.GetPlayerFromId(src)
        xPlayer.setJob(tonumber(jobGrade))
    end
end

function setPlayerGang(src, gangName, gangGrade)
    if Config.Use_QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(src)
        qbPlayer.SetJob(gangName, gangGrade)
    else
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer.setGang then
            xPlayer.setGang(gangName, tonumber(gangGrade))
        else
            print("Warning: setGang not available for ESX")
        end
    end
end

function addPlayerMoney(src, amount)
    if Config.Use_QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(src)
        qbPlayer.AddMoney("cash", amount, "DiscordDonatorPerks")
    else
        local xPlayer = ESX.GetPlayerFromId(src)
        xPlayer.addMoney(amount)
    end
end

-- OFFER HANDLERS
RegisterNetEvent('PatreonDonatorPerks:OfferMoney')
AddEventHandler('PatreonDonatorPerks:OfferMoney', function(src, label, amount)
    TriggerClientEvent('Perksy', src, {'Money', label, amount})
end)

RegisterNetEvent('PatreonDonatorPerks:OfferJob')
AddEventHandler('PatreonDonatorPerks:OfferJob', function(src, label, jobName, jobGrade)
    TriggerClientEvent('Perksy', src, {'job', label, jobName, jobGrade})
end)

-- GIVE JOB
RegisterNetEvent('PatreonDonatorPerks:GiveJob')
AddEventHandler('PatreonDonatorPerks:GiveJob', function(jobName, jobGrade)
    local src = source
    if not perkQueue[src] then return end
    local steamID = ExtractIdentifiers(src).steam
    local removeIndex = nil

    for i, perk in ipairs(perkQueue[src]) do
        local perkType = perk[1][1]
        local perkJob = perk[1][2]
        local perkGrade = perk[1][3]

        if (perkType:lower() == 'job' or perkType:lower() == 'gang') and perkJob == jobName and perkGrade == jobGrade then
            local rankName = perk[2]
            local perkID = perk[3]
            local datesOfPerks = MySQL.Sync.fetchAll('SELECT id FROM tebex_data WHERE identifier = @steam AND rankPackage = @rank AND acceptedPerkID = @perkID', {
                ['@steam'] = steamID,
                ['@rank'] = rankName,
                ['@perkID'] = perkID
            })

            local dateNow = os.time() + (60 * 60 * 24 * 30) -- 30 days later
            if datesOfPerks and #datesOfPerks >= 1 then
                MySQL.Async.execute('UPDATE tebex_data SET dateReceiveNext = @date WHERE id = @patData', {
                    ['@date'] = dateNow,
                    ['@patData'] = datesOfPerks[1].id
                })
            else
                MySQL.Async.execute('INSERT INTO tebex_data (identifier, playerName, dateReceiveNext, acceptedPerkID, rankPackage) VALUES (@ident, @playerName, @dateNext, @perkID, @rankPack)', {
                    ['@ident'] = steamID,
                    ['@playerName'] = GetPlayerName(src),
                    ['@dateNext'] = dateNow,
                    ['@perkID'] = perkID,
                    ['@rankPack'] = rankName
                })
            end

            if perkType:lower() == 'gang' then
                setPlayerGang(src, jobName, tonumber(jobGrade))
            else
                setPlayerJob(src, jobName, tonumber(jobGrade))
            end
            removeIndex = i
            break
        end
    end

    if removeIndex then
        table.remove(perkQueue[src], removeIndex)
    end
end)

-- GIVE MONEY
RegisterNetEvent('PatreonDonatorPerks:GiveMoney')
AddEventHandler('PatreonDonatorPerks:GiveMoney', function(amount)
    local src = source
    if not perkQueue[src] then return end
    local steamID = ExtractIdentifiers(src).steam
    local removeIndex = nil

    for i, perk in ipairs(perkQueue[src]) do
        local perkType = perk[1][1]
        local perkMoney = perk[1][2]

        if perkType == 'Money' and perkMoney == amount then
            local rankName = perk[2]
            local perkID = perk[3]
            local datesOfPerks = MySQL.Sync.fetchAll('SELECT id FROM tebex_data WHERE identifier = @steam AND rankPackage = @rank AND acceptedPerkID = @perkID', {
                ['@steam'] = steamID,
                ['@rank'] = rankName,
                ['@perkID'] = perkID
            })

            local dateNow = os.time() + (60 * 60 * 24 * 30)
            if datesOfPerks and #datesOfPerks >= 1 then
                MySQL.Async.execute('UPDATE tebex_data SET dateReceiveNext = @date WHERE id = @patData', {
                    ['@date'] = dateNow,
                    ['@patData'] = datesOfPerks[1].id
                })
            else
                MySQL.Async.execute('INSERT INTO tebex_data (identifier, playerName, dateReceiveNext, acceptedPerkID, rankPackage) VALUES (@ident, @playerName, @dateNext, @perkID, @rankPack)', {
                    ['@ident'] = steamID,
                    ['@playerName'] = GetPlayerName(src),
                    ['@dateNext'] = dateNow,
                    ['@perkID'] = perkID,
                    ['@rankPack'] = rankName
                })
            end

            addPlayerMoney(src, amount)
            removeIndex = i
            break
        end
    end

    if removeIndex then
        table.remove(perkQueue[src], removeIndex)
    end
end)

-- DENY JOB
RegisterNetEvent('PatreonDonatorPerks:DenyJob')
AddEventHandler('PatreonDonatorPerks:DenyJob', function(jobName, jobGrade)
    local src = source
    if not perkQueue[src] then return end
    local removeIndex = nil

    for i, perk in ipairs(perkQueue[src]) do
        local perkType = perk[1][1]
        local perkJob = perk[1][2]
        local perkGrade = perk[1][3]

        if (perkType:lower() == 'job' or perkType:lower() == 'gang') and perkJob == jobName and perkGrade == jobGrade then
            removeIndex = i
            break
        end
    end

    if removeIndex then
        table.remove(perkQueue[src], removeIndex)
    end
end)

-- CHECK PERKS
RegisterNetEvent('PatreonDonatorPerks:CheckPerks')
AddEventHandler('PatreonDonatorPerks:CheckPerks', function()
    local src = source
    local identifiers = ExtractIdentifiers(src)
    local steamID = identifiers.steam
    local discordID = identifiers.discord

    if not discordID then
        print("[PatreonDonatorPerks] " .. GetPlayerName(src) .. " has no Discord detected")
        return
    end

    local roleIDs = exports.Dead_Discord_API:GetDiscordRoles(src)
    if not roleIDs then
        print("[PatreonDonatorPerks] " .. GetPlayerName(src) .. " Discord roles could not be fetched")
        return
    end

    for i, roleData in ipairs(roleList) do
        local roleID = tostring(roleData[2])
        for _, playerRole in ipairs(roleIDs) do
            if roleID == tostring(playerRole) then
                local maxPerks = #roleData - 2
                local rankName = roleData[1]
                local currentPerks = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM tebex_data WHERE identifier = @steam AND rankPackage = @rank', {
                    ['@steam'] = steamID,
                    ['@rank'] = rankName
                }) or 0

                if currentPerks < maxPerks then
                    hasPerkAccess[src] = true
                    perkQueue[src] = perkQueue[src] or {}

                    for k = 3, #roleData do
                        local offer = roleData[k]
                        local offerName = offer[1]
                        local offerDetails = offer[2]

                        table.insert(perkQueue[src], {offerDetails, rankName, k - 2})

                        for l = 1, #offer do
                            local evt = offer[l]
                            if type(evt) == 'table' then
                                if evt[1]:lower() == 'job' or evt[1]:lower() == 'gang' then
                                    TriggerEvent('PatreonDonatorPerks:OfferJob', src, offerName, evt[2], evt[3])
                                elseif evt[1] == 'Money' then
                                    TriggerEvent('PatreonDonatorPerks:OfferMoney', src, offerName, evt[2])
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
