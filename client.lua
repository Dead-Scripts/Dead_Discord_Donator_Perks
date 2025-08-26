-------------------------------------
--- DiscordDonatorPerks by Dead ---
-------------------------------------
ESX = nil
offers = {}

-- ESX initialization
Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(10)
	end
end)

-- Request initial perks from server
Citizen.CreateThread(function()
	TriggerServerEvent("PatreonDonatorPerks:CheckPerks")
end)

-- Add new offer to stack
RegisterNetEvent('Perksy')
AddEventHandler('Perksy', function(offer)
	if type(offer) == "table" then
		table.insert(offers, offer)
	end
end)

-- Remove top offer from stack
RegisterNetEvent('PatreonDonatorPerks:Client:RemoveFromStack')
AddEventHandler('PatreonDonatorPerks:Client:RemoveFromStack', function()
	if #offers > 0 then
		table.remove(offers, 1)
	end
end)

-- Display active offers
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if #offers > 0 then
			local offer = offers[1]
			if type(offer) ~= "table" or #offer < 1 then
				-- Malformed offer, remove
				table.remove(offers, 1)
			else
				local label = offer[1]
				if label == 'Money' then
					local nameLab, amt = offer[2], offer[3]
					Draw2DText(0.5, 0.5, '~w~You have a ~g~' .. tostring(nameLab) .. ' ~w~donator perk', 1.0)
					Draw2DText(0.5, 0.55, '~y~Press ~b~ARROW_UP ~y~to accept or ~b~ARROW_DOWN ~y~to reject...', 1.0)
				else
					local lbl = label:lower()
					if lbl == 'job' or lbl == 'gang' then
						local nameLab, jobName, jobGrade = offer[2], offer[3], offer[4]
						Draw2DText(0.5, 0.5, '~w~You have a donator perk for ~p~' .. tostring(nameLab) 
							.. '~w~ of level grade ~p~' .. tostring(jobGrade), 1.0)
						Draw2DText(0.5, 0.55, '~y~Press ~b~ARROW_UP ~y~to accept or ~b~ARROW_DOWN ~y~to reject...', 1.0)
					end
				end
			end
		end
	end
end)

-- Handle input for accepting/rejecting perks
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if #offers > 0 then
			local offer = offers[1]
			if type(offer) ~= "table" or #offer < 1 then
				table.remove(offers, 1)
			else
				local label = offer[1]
				local lbl = label:lower()

				-- Accept perk
				if IsControlJustPressed(0, 172) then -- ARROW_UP
					if label == 'Money' then
						local amt = offer[3]
						TriggerServerEvent('PatreonDonatorPerks:GiveMoney', amt)
					elseif lbl == 'job' or lbl == 'gang' then
						local jobName, jobGrade = offer[3], offer[4]
						TriggerServerEvent('PatreonDonatorPerks:GiveJob', jobName, jobGrade)
					end
					TriggerEvent('PatreonDonatorPerks:Client:RemoveFromStack')
				end

				-- Reject perk
				if IsControlJustPressed(0, 173) then -- ARROW_DOWN
					if lbl == 'job' or lbl == 'gang' then
						local jobName, jobGrade = offer[3], offer[4]
						TriggerServerEvent('PatreonDonatorPerks:DenyJob', jobName, jobGrade)
					end
					TriggerEvent('PatreonDonatorPerks:Client:RemoveFromStack')
				end
			end
		end
	end
end)

-- Draw 2D text on screen
function Draw2DText(x, y, text, scale)
	SetTextFont(4)
	SetTextProportional(7)
	SetTextScale(scale, scale)
	SetTextColour(255, 255, 255, 255)
	SetTextDropShadow(0, 0, 0, 0, 255)
	SetTextEdge(4, 0, 0, 0, 255)
	SetTextOutline()
	SetTextJustification(0)
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(x, y)
end
