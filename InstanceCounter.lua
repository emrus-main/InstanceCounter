InstanceCounter = CreateFrame('Frame', 'InstanceCounter')
InstanceCounter:SetScript('OnEvent', function (addon, event, ...) addon[event](addon, ...) end)
InstanceCounter:SetScript('OnUpdate', function (addon, ...) addon["OnUpdate"](addon, ...) end)
InstanceCounter:RegisterEvent('ADDON_LOADED')
InstanceCounter.ADDONNAME = 'InstanceCounter'
InstanceCounter.ADDONVERSION = GetAddOnMetadata(InstanceCounter.ADDONNAME, 'Version')
InstanceCounter.ADDONAUTHOR = GetAddOnMetadata(InstanceCounter.ADDONNAME, 'Author')

local self = InstanceCounter
local L = InstanceCounterLocals
local C = {
	BLUE	= '|cff00ccff';
	GREEN	= '|cff66ff33';
	RED		= '|cffff3300';
	YELLOW	= '|cffffff00';
	WHITE	= '|cffffffff';
}
local db = {}

local ADDON_MESSAGE_PREFIX = 'INSTANCE_COUNTER'
local ADDON_MESSAGE_RESET_SPECIFIC = 'INSTANCE RESET\t'
local ADDON_MESSAGE_QUERY_RESETS = 'QUERY RESETS'
local ADDON_MESSAGE_REPLY_QUERY_RESETS = 'QUERY REPLY\t'
local print_debug = false

local name, realm, fullName

local currentSavedCountHour, currentSavedCountDay = 0
local AnnounceCountWhenAboveForHour = 3
local AnnounceCountWhenAboveForDay = 15

local InstancesPerHour = 5
local InstancesPerDay = 30
local LengthOfHour = 3600
local LengthOfDay = 86400
local ListCutOffTime = 86400
local UpdateFrequency = 5


function InstanceCounter:ADDON_LOADED(frame)
	if frame ~= InstanceCounter.ADDONNAME then return end
	self.debug('ADDON_LOADED')
	
	self:UnregisterEvent('ADDON_LOADED')
	self.ADDON_LOADED = nil
	
	-- Init DB
	if InstanceCounterDB == nil then InstanceCounterDB = {} end
	if InstanceCounterDB.List == nil then InstanceCounterDB.List = {} end
	if InstanceCounterDB.DelayedResetList == nil then InstanceCounterDB.DelayedResetList = {} end
	if InstanceCounterDB.PlayerLogoutLocation == nil then InstanceCounterDB.PlayerLogoutLocation = {} end
	db = InstanceCounterDB
	
	-- Register Events
	self.ClearOld()
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:RegisterEvent('CHAT_MSG_ADDON')

	self:RegisterEvent('PLAYER_CAMPING')

	self:RegisterEvent('ZONE_CHANGED')
	self:RegisterEvent('ZONE_CHANGED_INDOORS')
	self:RegisterEvent('ZONE_CHANGED_NEW_AREA')

	if # db.List >= 1 then
		self:RegisterEvent('CHAT_MSG_SYSTEM')
	end
	

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
	if not successfulRequest then
		self.error(L['TOO_MANY_PREFIXES'])
	end

	self.Delayed = true
	self.Zoned = true
end

function InstanceCounter:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	self.debug('PLAYER_ENTERING_WORLD')
	if isInitialLogin then self.debug("Initial Login") end
	if isReloadingUi then self.debug("Reload") end

	self.Delayed = isInitialLogin
	self.Zoned = not isInitialLogin

	name, realm = UnitFullName("player")
	fullName = name .. "-" .. realm

	if self.Delayed then return end

	self.ClearOld()
	if IsInInstance() then 
		self.UpdateTimeInInstance()
	end
end

function InstanceCounter:PLAYER_CAMPING()
	self.debug('PLAYER_CAMPING')
	db.PlayerLogoutLocation[fullName] = self.getDetailedLocation();
end

function InstanceCounter:ZONE_CHANGED()
	self.debug('ZONE_CHANGED')
	self.ZonedIn()
end
function InstanceCounter:ZONE_CHANGED_INDOORS()
	self.debug('ZONE_CHANGED_INDOORS')
	self.ZonedIn()
end
function InstanceCounter:ZONE_CHANGED_NEW_AREA()
	self.debug('ZONE_CHANGED_NEW_AREA')
	self.ZonedIn()
end

function InstanceCounter.ZonedIn()
	if not self.Zoned then
		self.checkForOfflineReset()
		self.Zoned = true
	end
end

function InstanceCounter:CHAT_MSG_SYSTEM(msg)
	if msg == TRANSFER_ABORT_TOO_MANY_INSTANCES then
		self.ClearOld()
		self.PrintTimeUntilReset()
	end
	
	if msg == ERR_LEFT_GROUP_YOU then
		self.ResetInstancesByKey('character', fullName)
	end
	
	local name = string.match(msg, '(.*) has been reset')
	if name ~= nil then
		if IsInGroup() then
			self.BroadcastReset(name)
		end	
	end
end

function InstanceCounter:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == ADDON_MESSAGE_PREFIX and (channel == 'PARTY' or channel == 'RAID' or channel == 'WHISPER') and sender ~= fullName then
		local name = string.match(msg, ADDON_MESSAGE_RESET_SPECIFIC .. '(.+)')
		if (channel == 'PARTY' or channel == 'RAID') and name ~= nil then
			self.ResetInstancesByKey('name', name)
		end

		if (channel == 'PARTY' or channel == 'RAID') and msg == ADDON_MESSAGE_QUERY_RESETS then
			self.ReplyToQueryResetRequest(sender)
		end

		local t = string.match(msg, ADDON_MESSAGE_REPLY_QUERY_RESETS .. '([0-9]+)')
		if channel == 'WHISPER' and t ~= nil then
			self.ResetInstancesOlderThen(fullName, tonumber(t))
		end
	elseif prefix == 'instHistory' and not UnitIsUnit(sender, "player") then
        if msg == 'GENERATION_ADVANCE' then
			self.ResetInstancesByKey('character', fullName)
			self.print(L["INSTANCE_RESET"])
        end
	end
end

function InstanceCounter:OnUpdate(sinceLastUpdate)
	self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
	if self.sinceLastUpdate >= UpdateFrequency then
		self.sinceLastUpdate = 0

		if self.Delayed then
			if IsInGroup() then
				self.BroadcastQueryResets()
			end
			self.Delayed = false
			return
		end
		if not self.Zoned then
			InstanceCounter.ZonedIn()
		end

		if not self.Zoned then
			return
		end

		self.ClearOld()

		countHour, countDay = InstanceCounter.InstanceCount()

		if countHour < currentSavedCountHour and currentSavedCountHour > SavedCountAnnounceHourLimit then
			self.print(format(L['OPEN_INSTANCES_DAY'], countHour))
		end
		
		if countHour < currentSavedCountHour and currentSavedCountDay > SavedCountAnnounceDayLimit then
			self.print(format(L['OPEN_INSTANCES_DAY'], countDay))
		end

		currentSavedCountHour = countHour
		currentSavedCountDay = countDay
		
		if IsInInstance() then
			self.UpdateTimeInInstance()
		end
	end
end

function InstanceCounter.BroadcastReset(name)
	self.debug("BroadcastReset")
	if IsInRaid() then
		success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_RESET_SPECIFIC .. name, 'RAID')
	elseif IsInGroup() then
		success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_RESET_SPECIFIC .. name, 'PARTY')
	end
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.BroadcastQueryResets()
	self.debug("BroadcastQueryResets")
	if IsInRaid() then
		success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_QUERY_RESETS, 'RAID')
	elseif IsInGroup() then
		success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_QUERY_RESETS, 'PARTY')
	end
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.ReplyQueryResets(name, t)
	self.debug("ReplyQueryResets ".. name)
	success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_REPLY_QUERY_RESETS .. t, 'WHISPER', name)
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.getDetailedLocation()
	self.debug("getDetailedLocation")
	local name, instanceType, difficultyID = GetInstanceInfo()
        
	if instanceType ~= "party" and instanceType ~= "raid" then return nil end
	
	return {
		name = name;
		instanceType = instanceType;
		difficultyID = difficultyID;
		subzone = GetSubZoneText();
	}
end


function InstanceCounter.checkForOfflineReset()
	self.debug("checkForOfflineReset")
	if db.PlayerLogoutLocation[fullName] == nil then return end

	self.debug("Logout Location: " .. db.PlayerLogoutLocation[fullName].name .. ' - ' .. db.PlayerLogoutLocation[fullName].subzone)
	local currentLocation = self.getDetailedLocation()
	if currentLocation ~= nil and 
	   db.PlayerLogoutLocation[fullName].name == currentLocation.name and 
	   db.PlayerLogoutLocation[fullName].subzone ~= currentLocation.subzone then
		self.ResetInstancesByKey('character', fullName)
		self.debug('Offline reset from location')
		self.print(L['OFFLINE_RESET'])
	end
	db.PlayerLogoutLocation[fullName] = nil
end


function InstanceCounter.UpdateTimeInInstance()
	local name, instanceType, difficultyID = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	
	for i = # db.List, 1, -1 do
		if db.List[i].name == name and 
			db.List[i].instanceType == instanceType and 
			db.List[i].difficultyID == difficultyID and 
			db.List[i].character == fullName and
			not db.List[i].reset then
			db.List[i].lastSeen = time()
			return
		end
	end
	if IsInInstance() then 
		self.AddCurrentInstance()
	end	
end

function InstanceCounter.AddCurrentInstance()
	self.debug("AddCurrentInstance")
	local name, instanceType, difficultyID = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	
	self.AddInstance(name, instanceType, difficultyID)
	
	countHour, countDay = self.InstanceCount()

	if countHour >= AnnounceCountWhenAboveForHour and countDay >= AnnounceCountWhenAboveForDay then
		self.PrintTimeUntilReset()
	elseif countHour >= AnnounceCountWhenAboveForHour then
		self.PrintTimeUntilResetHour()
	elseif countDay >= AnnounceCountWhenAboveForDay then
		self.PrintTimeUntilResetDay()
	end
	
end

function InstanceCounter.AddInstance(name, instanceType, difficultyID)
	self.debug("AddInstance")
	if self.IsInstanceInList(name, instanceType, difficultyID) then return end
	
	local instance = {
		name		= name;
		instanceType= instanceType;
		difficultyID= difficultyID;
		character	= fullName;
		reset		= false;
		saved		= self.IsPlayerSavedToInstance(name, instanceType, difficultyID);
		entered		= time();
		lastSeen	= time();
		resetTime	= nil;
	}
	
	table.insert(db.List, instance)
	self.SortInstances()
	self:RegisterEvent('CHAT_MSG_SYSTEM')
end

function InstanceCounter.ClearInstances()
	self.debug("ClearInstances")
	db.List = {}
	currentSavedCountHour = 0
	currentSavedCountDay = 0
	self:UnregisterEvent('CHAT_MSG_SYSTEM')
end

function InstanceCounter.ClearOld()  -- DOUBLE CHECK!
	local t = time()
	local removed = false
	
	for i = # db.List, 1, -1 do
		if t - db.List[i].lastSeen > ListCutOffTime then
			self.debug(format("Removing instance %s from list due to not being seen in 24 hours", db.List[i].name))
			table.remove(db.List, i)
			removed = true
		end
	end

	for i = # db.DelayedResetList, 1, -1 do
		if t - db.DelayedResetList[i].resetTime > ListCutOffTime then
			table.remove(db.DelayedResetList, i)
		end
	end

	self.SortInstances()

	if # db.List == 0 then
		self:UnregisterEvent('CHAT_MSG_SYSTEM')
	end
	return removed
end

function InstanceCounter.IsInstanceInList(name, instanceType, difficultyID)	
	for i = 1, # db.List do
		if not db.List[i].reset and 
		   db.List[i].name == name and 
		   db.List[i].instanceType == instanceType and 
		   db.List[i].difficultyID == difficultyID and 
		   db.List[i].character == fullName then
			return true
		end
	end
	
	return false
end

function InstanceCounter.IsPlayerSavedToInstance(name, instanceType, difficultyID)
	if instanceType == 'party' and difficultyID == 1 then return false end
	
	for i = 1, GetNumSavedInstances() do
		local i_name, _, _, i_difficultyID, i_locked = GetSavedInstanceInfo(i)
		if i_name == name and i_difficultyID == difficultyID and i_locked then
			return true
		end
	end
	
	return false
end

function InstanceCounter.ResetInstancesForParty()
	self.debug("ResetInstancesForParty")
	self.ResetInstancesByKey('character', fullName)
	t = time()
	-- For alts in group --
	for groupindex = 1, GetNumGroupMembers() do
		local playername, _, _, _, _, _, _, online = GetRaidRosterInfo(groupindex)
		if playername ~= nil and not online then
			if not string.find(playername,'-') then
				playername = playername .. '-' .. realm
			end

			self.ResetInstancesByKey('character', playername)
			self.AddToDelayedReset(playername, t)
		end
	end
end

function InstanceCounter.ResetInstancesOlderThen(playername, t)
	self.debug("ResetInstancesOlderThen")
	for i = 1, # db.List do
		if db.List[i].character == playername and 
		   db.List[i].lastSeen < t and
		   not db.List[i].reset and 
		   not db.List[i].saved then
			self.print(L["OFFLINE_RESET"])
			self.debug('Offline reset from location')
			db.List[i].resetTime = time()
			db.List[i].reset = true
		end
	end
end

function InstanceCounter.ResetInstancesByKey(key, value)
	self.debug("ResetInstancesByKey")
	for i = 1, # db.List do
		if db.List[i][key] == value and 
		   not db.List[i].reset and 
		   not db.List[i].saved then
			db.List[i].resetTime = time()
			db.List[i].reset = true
		end
	end
end

function InstanceCounter.OnResetInstances()
	if not IsInInstance() and (UnitIsGroupLeader('player') or not IsInGroup()) then
		self.ResetInstancesForParty()
	end
end

function InstanceCounter.SortInstances()
	table.sort(db.List, function(a, b) return a.entered < b.entered end)
end

function InstanceCounter.AddToDelayedReset(playername, t)
	self.debug("ResetInstancesByKey")
	for i = # db.DelayedResetList, 1, -1 do
		if db.DelayedResetList[i].name == playername then
			db.DelayedResetList[i].resetTime = t
			return
		end	
	end

	local reset = {
		name		= playername;
		resetTime	= t;
	}
	table.insert(db.DelayedResetList, reset)
end

function InstanceCounter.ReplyToQueryResetRequest(playername)
	self.debug("ReplyToQueryResetRequest")
	for i = # db.DelayedResetList, 1, -1 do
		if db.DelayedResetList[i].name == playername then
			InstanceCounter.ReplyQueryResets(playername, db.DelayedResetList[i].resetTime)
			table.remove(db.DelayedResetList, i)
			return
		end
	end
end

function InstanceCounter.TimeRemaining(t, period)
	local t = period - (time() - t)
	local neg = ''

	if t < 0 then 
		t = -t
		neg = '-'
	end

	local sec = t%60
	local min = floor(t/60)%60
	local hour = floor(t/3600)

	if hour > 0 then 
		return neg .. format("%.2d:%.2d:%.2d", hour, min, sec)
	end
	return neg .. format("%.2d:%.2d", min, sec)
end

function InstanceCounter.InstanceCount()
	local t = time()
	local hourCount = 0
	local dayCount = 0

	if # db.List > 0 then
		for i,v in ipairs(db.List) do
			if t - v.lastSeen <= LengthOfHour then
				hourCount = hourCount + 1
			end
			if t - v.lastSeen <= LengthOfDay then
				dayCount = dayCount + 1
			end
		end		
	end
	return hourCount, dayCount
end

function InstanceCounter.NextReset(Period)
	local t = time()
	local lastSeen = t

	if # db.List > 0 then
		for i,v in ipairs(db.List) do
			if (t - v.lastSeen <= Period) and (v.lastSeen < lastSeen) then
				lastSeen = v.lastSeen
			end
		end		
	end
	return lastSeen
end


------ PRINT ------
function InstanceCounter.PrintTimeUntilReset()
	self.ClearOld()

	local hourCount, dayCount = self.InstanceCount()
	if hourCount >= 1 then
		self.print(format(L['TIME_REMAINING_HOUR'], hourCount, self.TimeRemaining(self.NextReset(LengthOfHour), LengthOfHour)))
	else
		self.print(L['NO_INSTANCES_HOUR'])
	end
	if dayCount >= 1 then
		self.print(format(L['TIME_REMAINING_DAY'], dayCount, self.TimeRemaining(self.NextReset(LengthOfDay), LengthOfDay)))
	else
		self.print(L['NO_INSTANCES_DAY'])
	end
end

function InstanceCounter.PrintTimeUntilResetHour()
	self.ClearOld()
	
	local hourCount, dayCount = self.InstanceCount()
	if hourCount >= 1 then
		self.print(format(L['TIME_REMAINING_HOUR'], hourCount, self.TimeRemaining(self.NextReset(LengthOfHour), LengthOfHour)))
	else
		self.print(L['NO_INSTANCES_HOUR'])
	end
end

function InstanceCounter.PrintTimeUntilResetDay()
	self.ClearOld()

	local hourCount, dayCount = self.InstanceCount()
	if dayCount >= 1 then
		self.print(format(L['TIME_REMAINING_DAY'], dayCount, self.TimeRemaining(self.NextReset(LengthOfDay), LengthOfDay)))
	else
		self.print(L['NO_INSTANCES_DAY'])
	end
end


function InstanceCounter.PrintInstances()
	self.ClearOld()
	
	local hourCount, dayCount = self.InstanceCount()
	if hourCount >= 1 then
		self.print(L['PRINT_DESCRIPTION_HOUR'])
		print(L['PRINT_HEADERS'])
		
		self.PrintInstancesHelper(LengthOfHour)
	else
		self.print(L['NO_INSTANCES_HOUR'])
	end
end

function InstanceCounter.PrintInstancesAll()
	self.ClearOld()
	
	local hourCount, dayCount = self.InstanceCount()
	if dayCount >= 1 then
		self.print(L['PRINT_DESCRIPTION_DAY'])
		print(L['PRINT_HEADERS'])
		
		self.PrintInstancesHelper(LengthOfDay)
	else
		self.print(L['NO_INSTANCES_DAY'])
	end
end

function InstanceCounter.PrintInstancesHelper(period)
	local t = time()
	for i,v in ipairs(db.List) do
		if t - v.lastSeen <= period then
			local name = strsplit('-', v.character, 2)
			print(C.WHITE .. format(L['PRINT_ROW'], 
					name, 
					v.reset and (C.RED .. v.name .. C.WHITE) or v.name, 
					self.TimeRemaining(v.lastSeen, period)))
		end
	end
end


function InstanceCounter.PrintInstancesToChat(chat, channel)
	self.ClearOld()
	
	local hourCount, dayCount = self.InstanceCount()
	if hourCount >= 1 then
		SendChatMessage(L['NAME'] .. ': ' .. L['PRINT_DESCRIPTION_HOUR'], chat ,"Common", channel)
		SendChatMessage(L['PRINT_HEADERS'], chat ,"Common", channel)
		self.PrintInstancesToChatHelper(chat, channel, LengthOfHour)
	else
		self.print(L['NO_INSTANCES_HOUR'])
	end
end

function InstanceCounter.PrintInstancesToChatAll(chat, channel)
	self.ClearOld()
	
	local hourCount, dayCount = self.InstanceCount()
	if dayCount >= 1 then
		SendChatMessage(L['NAME'] .. ': ' .. L['PRINT_DESCRIPTION_DAY'], chat ,"Common", channel)
		SendChatMessage(L['PRINT_HEADERS'], chat ,"Common", channel)
		self.PrintInstancesToChatHelper(chat, channel, LengthOfDay)
	else
		self.print(L['NO_INSTANCES_DAY'])
	end
end

function InstanceCounter.PrintInstancesToChatHelper(chat, channel, period)
	local t = time()
	for i,v in ipairs(db.List) do
		if t - v.lastSeen <= period then		
			SendChatMessage(format(L['PRINT_ROW'], v.character, v.name, self.TimeRemaining(v.lastSeen, period)), chat ,"Common", channel)
		end
	end
end

function InstanceCounter.PrintOptions()
	local cmd_color = C.RED
	local cmd_text = C.WHITE
	
	self.print(cmd_text .. format(L['CMD_HEADER_DESC'], 
				L['CMD_LONG'], cmd_color .. L['CMD_CMD'] .. cmd_text,
				L['CMD_SHORT'], cmd_color .. L['CMD_CMD'] .. cmd_text))

	for k, v in pairs(L['CMD']) do
		self.print(cmd_text .. format(L['CMD_DESC'], cmd_color .. v['CMD'] .. cmd_text, cmd_color .. v['ARGS'] .. cmd_text, v['DESCRIPTION']))
	end
end

function InstanceCounter.debug(msg)
	if(print_debug) then
		print(C.RED .. L['NAME'] .. ': ' .. C.YELLOW .. msg)
	end
end

function InstanceCounter.print(msg)
	print(C.GREEN .. L['NAME'] .. ': ' .. C.YELLOW .. msg)
end

function InstanceCounter.error(msg)
	print(C.GREEN .. L['NAME'] .. ': ' .. C.RED .. msg)
end

------

hooksecurefunc('ResetInstances', function(...)
	self.OnResetInstances()
end)

SlashCmdList['InstanceCounter'] = function(txt)
	local txt, arg1, arg2 = strsplit(" ", txt, 3)
	if txt == L['CMD']['CLEAR']['CMD'] then
		InstanceCounter.ClearInstances()
		self.print(L['LIST_CLEARED'])
	elseif txt == L['CMD']['PRINT']['CMD'] then
		InstanceCounter.PrintInstances()
	elseif txt == L['CMD']['PRINTALL']['CMD'] then
		InstanceCounter.PrintInstancesAll()
	elseif txt == L['CMD']['RESET']['CMD'] then
		InstanceCounter.ResetInstancesForParty()
		self.print(L['MANUAL_RESET'])
	elseif txt == L['CMD']['TIME']['CMD'] then
		InstanceCounter.PrintTimeUntilReset()
	elseif txt == L['CMD']['REPORT']['CMD'] then
		InstanceCounter.PrintInstancesToChat(arg1, arg2)
	elseif txt == L['CMD']['REPORTALL']['CMD'] then
		InstanceCounter.PrintInstancesToChatAll(arg1, arg2)
	else
		InstanceCounter.PrintOptions()
	end
end