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

function InstanceCounter:ADDON_LOADED(frame)
	if frame ~= InstanceCounter.ADDONNAME then return end
	
	self:UnregisterEvent('ADDON_LOADED')
	self.ADDON_LOADED = nil
	
	-- Init DB
	if InstanceCounterDB == nil then InstanceCounterDB = {} end
	if InstanceCounterDB.List == nil then InstanceCounterDB.List = {} end
	if InstanceCounterDB.DelayedResetList == nil then InstanceCounterDB.DelayedResetList = {} end
	db = InstanceCounterDB
	
	-- Register Events
	self.ClearOld()
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:RegisterEvent('CHAT_MSG_ADDON')

	self:RegisterEvent('PLAYER_CAMPING')
	self:RegisterEvent('PLAYER_LEAVING_WORLD')	
	

	if # db.List >= 1 then
		self:RegisterEvent('CHAT_MSG_SYSTEM')
	end
	
	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
	if not successfulRequest then
		self.error(L['TOO_MANY_PREFIXES'])
	end

	if IsInGroup() then
		self.Delayed = true
		self.BroadcastQueryResets()
	end
end

function InstanceCounter:PLAYER_ENTERING_WORLD()
	self.checkForOfflineReset()

	if self.Delayed then return end

	self.ClearOld()
	if IsInInstance() then 
		self.AddCurrentInstance()
	end
end

function InstanceCounter:PLAYER_LEAVING_WORLD()
	db.logoutLocation = self.getDetailedLocation();
end

function InstanceCounter:PLAYER_CAMPING()
    db.logoutLocation = self.getDetailedLocation();
end

function InstanceCounter:CHAT_MSG_SYSTEM(msg)
	if msg == TRANSFER_ABORT_TOO_MANY_INSTANCES then
		self.ClearOld()
		self.PrintTimeUntilReset()
	end
	
	if msg == ERR_LEFT_GROUP_YOU then
		self.ResetInstancesByKey('character', UnitName('player'))
	end
	
	local name = string.match(msg, '(.*) has been reset')
	if name ~= nil then
		self.ResetInstancesByKey('name', name)
		if IsInGroup() then
			self.BroadcastReset(name)
		end	
	end
end

function InstanceCounter:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == ADDON_MESSAGE_PREFIX and (channel == 'PARTY' or channel == 'WHISPER') and not UnitIsUnit(sender, "player") then
		local name = string.match(msg, ADDON_MESSAGE_RESET_SPECIFIC .. '(.+)')
		if channel == 'PARTY' and name ~= nil then
			self.ResetInstancesByKey('name', name)
		end

		if channel == 'PARTY' and msg == ADDON_MESSAGE_QUERY_RESETS then
			self.ReplyToQueryResetRequest(sender)
		end

		local t = string.match(msg, ADDON_MESSAGE_REPLY_QUERY_RESETS .. '([0-9]+)')
		if channel == 'WHISPER' and t ~= nil then
			self.ResetInstancesOlderThen(UnitName('player'), tonumber(t))
		end
	elseif prefix == 'instHistory' and not UnitIsUnit(sender, "player") then
        if msg == 'GENERATION_ADVANCE' then
			self.ResetInstancesByKey('character', UnitName('player'))
        end
	end
end

function InstanceCounter:OnUpdate(sinceLastUpdate)
	self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate
	if self.sinceLastUpdate >= 5 then
		self.sinceLastUpdate = 0

		if self.Delayed then
			self.Delayed = false
			InstanceCounter:PLAYER_ENTERING_WORLD()
		end

		if self.ClearOld() and # db.List == 4 then
			self.print(L['OPEN_INSTANCES'])
		end
		
		if IsInInstance() then
			self.UpdateTimeInInstance()
		end
	end
end

function InstanceCounter.BroadcastReset(name)
	success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_RESET_SPECIFIC .. name, 'PARTY')
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.BroadcastQueryResets()
	success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_QUERY_RESETS, 'PARTY')
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.ReplyQueryResets(name, t)
	success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_REPLY_QUERY_RESETS .. t, 'WHISPER', name)
	if not success then
		self.error(L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.getDetailedLocation()
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
	if db.logoutLocation == nil then return end

	local currentLocation = self.getDetailedLocation()

	if currentLocation ~= nil and 
	   db.logoutLocation.name == currentLocation.name and 
	   db.logoutLocation.subzone ~= currentLocation.subzone then
		self.ResetInstancesByKey('character', UnitName('player'))
		self.print(L['OFFLINE_RESET'])
	end
	db.logoutLocation = nil
end


function InstanceCounter.UpdateTimeInInstance()
	local name, instanceType, difficultyID = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	
	local character = UnitName('player')

	for i = # db.List, 1, -1 do
		if db.List[i].name == name and 
			db.List[i].instanceType == instanceType and 
			db.List[i].difficultyID == difficultyID and 
			db.List[i].character == character then
			db.List[i].lastSeen = time()
			return
		end
	end
end

function InstanceCounter.AddCurrentInstance()
	local name, instanceType, difficultyID = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	
	self.AddInstance(name, instanceType, difficultyID)
	
	if # db.List >= 5 then
		self.PrintTimeUntilReset()
	end
end

function InstanceCounter.AddInstance(name, instanceType, difficultyID)
	if self.IsInstanceInList(name, instanceType, difficultyID) then return end
	
	local instance = {
		name		= name;
		instanceType= instanceType;
		difficultyID= difficultyID;
		character	= UnitName('player');
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
	db.List = {}
	self:UnregisterEvent('CHAT_MSG_SYSTEM')
end

function InstanceCounter.ClearOld()
	local t = time()
	local removed = false
	
	for i = # db.List, 1, -1 do
		if t - db.List[i].lastSeen > 3600 then
			table.remove(db.List, i)
			removed = true
		end
	end

	for i = # db.DelayedResetList, 1, -1 do
		if t - db.DelayedResetList[i].resetTime > 3600 then
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
	local character = UnitName('player')
	
	for i = 1, # db.List do
		if not db.List[i].reset and 
		   db.List[i].name == name and 
		   db.List[i].instanceType == instanceType and 
		   db.List[i].difficultyID == difficultyID and 
		   db.List[i].character == character then
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
	self.ResetInstancesByKey('character', UnitName('player'))
	t = time()
	-- For alts in group --
	for groupindex = 1, GetNumGroupMembers() do
		local playername, _, _, _, _, _, _, online = GetRaidRosterInfo(groupindex)
		if playername ~= nil and not online then
			self.ResetInstancesByKey('character', playername)
			self.AddToDelayedReset(playername, t)
		end
	end
end

function InstanceCounter.ResetInstancesOlderThen(playername, t)
	for i = 1, # db.List do
		if db.List[i].character == playername and 
		   db.List[i].lastSeen < t and
		   not db.List[i].reset and 
		   not db.List[i].saved then
			db.List[i].resetTime = time()
			db.List[i].reset = true
		end
	end
end

function InstanceCounter.ResetInstancesByKey(key, value)
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

function InstanceCounter.ReplyToQueryResetRequest(playerrealmname)
	local name = strsplit('-', playerrealmname, 2)

	for i = # db.DelayedResetList, 1, -1 do
		if db.DelayedResetList[i].name == name then
			InstanceCounter.ReplyQueryResets(playerrealmname, db.DelayedResetList[i].resetTime)
			table.remove(db.DelayedResetList, i)
			return
		end
	end
end

function InstanceCounter.TimeRemaining(t)
	local t = 3600 - (time() - t)
	local neg = ''

	if t < 0 then 
		t = -t
		neg = '-'
	end

	return neg .. format("%.2d:%.2d", floor(t/60), t%60)
end

------ PRINT ------
function InstanceCounter.PrintTimeUntilReset()
	if # db.List > 0 then
		if # db.List >= 5 then
			self.print(format(L['TIME_REMAINING'], self.TimeRemaining(db.List[1].lastSeen)))
		else
			self.print(format(L['ONLY_ENTERED'], # db.List))
		end
	else
		self.print(L['NO_INSTANCES'])
	end
end

function InstanceCounter.PrintInstances()
	self.ClearOld()
	
	if # db.List > 0 then
		self.print(L['PRINT_DESCRIPTION'])
		print(L['PRINT_HEADERS'])
		for i = 1, # db.List do
			print(C.WHITE .. format(L['PRINT_ROW'], 
					db.List[i].character, 
					db.List[i].reset and (C.RED .. db.List[i].name .. C.WHITE) or db.List[i].name, 
					self.TimeRemaining(db.List[i].lastSeen)))
		end
	else
		self.print(L['NO_INSTANCES'])
	end
end

function InstanceCounter.PrintInstancesToChat(chat, channel)
	self.ClearOld()
	
	if # db.List > 0 then
		SendChatMessage(L['NAME'] .. ': ' .. L['PRINT_DESCRIPTION'], chat ,"Common", channel)
		SendChatMessage(L['PRINT_HEADERS'], chat ,"Common", channel)
		for i = 1, # db.List do
			SendChatMessage(format(L['PRINT_ROW'], db.List[i].character, db.List[i].name, self.TimeRemaining(db.List[i].lastSeen)), chat ,"Common", channel)
		end
	else
		self.print(L['NO_INSTANCES'])
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
	elseif txt == L['CMD']['RESET']['CMD'] then
		InstanceCounter.ResetInstancesForParty()
		self.print(L['MANUAL_RESET'])
	elseif txt == L['CMD']['TIME']['CMD'] then
		InstanceCounter.PrintTimeUntilReset()
	elseif txt == L['CMD']['REPORT']['CMD'] then
		InstanceCounter.PrintInstancesToChat(arg1, arg2)
	else
		InstanceCounter.PrintOptions()
	end
end