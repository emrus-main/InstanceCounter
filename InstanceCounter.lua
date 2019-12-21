InstanceCounter = CreateFrame('Frame', 'InstanceCounter')
InstanceCounter:SetScript('OnEvent', function (addon, event, ...) addon[event](addon, ...) end)
InstanceCounter:SetScript('OnUpdate', function (addon, ...) addon["OnUpdate"](addon, ...) end)
InstanceCounter:RegisterEvent('ADDON_LOADED')
InstanceCounter.ADDONNAME = 'InstanceCounter'
InstanceCounter.ADDONVERSION = GetAddOnMetadata(InstanceCounter.ADDONNAME, 'Version');
InstanceCounter.ADDONAUTHOR = GetAddOnMetadata(InstanceCounter.ADDONNAME, 'Author');

local self = InstanceCounter;
local L = InstanceCounterLocals
local C = {
	BLUE	= '|cff00ccff';
	GREEN	= '|cff66ff33';
	RED		= '|cffff3300';
	YELLOW	= '|cffffff00';
	WHITE	= '|cffffffff';
}
local db = {};
local prefix = C.GREEN .. L['NAME'] .. C.WHITE .. ': '

local ADDON_MESSAGE_PREFIX = 'INSTANCE_COUNTER'
local ADDON_MESSAGE_RESET_SPECIFIC = 'INSTANCE RESET\t'


function InstanceCounter:ADDON_LOADED(frame)
	if (frame ~= InstanceCounter.ADDONNAME) then return end
	
	self:UnregisterEvent('ADDON_LOADED');
	self.ADDON_LOADED = nil;
	
	-- Init DB
	if (InstanceCounterDB == nil) then InstanceCounterDB = {} end
	if (InstanceCounterDB.List == nil) then InstanceCounterDB.List = {} end
	db = InstanceCounterDB;
	
	-- Register Events
	self.ClearOldInstances();
	self:RegisterEvent('PLAYER_ENTERING_WORLD');
	self:RegisterEvent('CHAT_MSG_ADDON');
	
	if (# db.List >= 1) then
		self:RegisterEvent('CHAT_MSG_SYSTEM');
	end	

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
	if not successfulRequest then
		print(prefix .. C.RED .. L['TOO_MANY_PREFIXES'])
	end
end

function InstanceCounter:PLAYER_ENTERING_WORLD()
	self.ClearOldInstances();
	
	if (IsInInstance()) then 
		self.AddCurrentInstance()
	end		
end

function InstanceCounter:CHAT_MSG_SYSTEM(msg)
	if (msg == TRANSFER_ABORT_TOO_MANY_INSTANCES) then
		self.ClearOldInstances()
		self.PrintTimeUntilReset()
	end
	
	if (msg == ERR_LEFT_GROUP_YOU) then
		self.ResetInstancesForCharacter(UnitName('player'))
	end

	instanceName = string.match(msg, '(.*) has been reset')
	if (instanceName ~= nil) then
		self.ResetInstanceByName(instanceName)
		if (IsInGroup()) then
			self.Broadcast(instanceName)
		end
	end
end

function InstanceCounter:CHAT_MSG_ADDON(prefix, msg, type, sender)
	if(prefix ~= ADDON_MESSAGE_PREFIX) then return end
	if(type ~= 'PARTY') then return end

	instanceName = string.match(msg, ADDON_MESSAGE_RESET_SPECIFIC .. '(.+)')
	if (instanceName ~= nil) then
		self.ResetInstanceByName(instanceName)
	end
end


function InstanceCounter:OnUpdate(sinceLastUpdate)
	self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate;
	if ( self.sinceLastUpdate >= 5 ) then
		self.sinceLastUpdate = 0;

		self.ClearOldAndPrint()
		
		if (not IsInInstance()) then return end
		
		local name, instanceType, difficultyID = GetInstanceInfo();
		if ((instanceType ~= "party") and (instanceType ~= "raid")) then return end

		local character = UnitName('player')

		for i = 1, # db.List do
			if (db.List[i].reset == false and 
				db.List[i].name == name and 
				db.List[i].type == instanceType and 
				db.List[i].difficulty == difficultyID and 
				db.List[i].character == character) then
				db.List[i].last_seen = time();
			end
		end
		
	end
end

function InstanceCounter.Broadcast(instanceName)
	success = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, ADDON_MESSAGE_RESET_SPECIFIC .. instanceName, 'PARTY')
	if not success then
		print(prefix .. C.RED .. L['MESSAGE_NOT_SENT'])
	end
end

function InstanceCounter.AddCurrentInstance()
	local name, instanceType, difficultyID = GetInstanceInfo();
	if ((instanceType ~= "party") and (instanceType ~= "raid")) then return end

	if ((instanceType == 'party') and (difficultyID == 1)) then
		self.AddInstance(name, instanceType, difficultyID, false);		
	else
		local isSaved = self.IsPlayerSavedToInstance(name, difficultyID);
		self.AddInstance(name, instanceType, difficultyID, isSaved);
	end

	self:RegisterEvent('CHAT_MSG_SYSTEM');
	if (# db.List >= 5) then
		self.PrintTimeUntilReset()
	end
end

function InstanceCounter.AddInstance(name, type, difficulty, saved)
	if (self.IsInstanceInList(name, type, difficulty)) then return end

	local instance = {
		character	= UnitName('player');
		difficulty	= difficulty;
		name		= name;
		reset		= false;
		saved		= saved;
		time		= time();
		last_seen	= time();
		reset_time	= nil;
		type		= type;
	}
	
	table.insert(db.List, instance);
	self.SortInstances();
end


function InstanceCounter.ClearInstances()
	db.List = {};
	self:UnregisterEvent('CHAT_MSG_SYSTEM');
end

function InstanceCounter.ClearOldInstances()
	local t = time()
	local removed = false
	
	for i = # db.List, 1, -1 do
		if (t - db.List[i].last_seen > 3600) then
			table.remove(db.List, i)
			removed = true
		end
	end

	self.SortInstances();

	if # db.List == 0 then
		self:UnregisterEvent('CHAT_MSG_SYSTEM');
	end
	return removed
end

function InstanceCounter.IsInstanceInList(name, type, difficulty)
	for i = 1, # db.List do
		if ((name == db.List[i].name) and (type == db.List[i].type) and (difficulty == db.List[i].difficulty) and (UnitName('player') == db.List[i].character)) then
			if (db.List[i].saved) then return true end
			if (not db.List[i].reset) then return true end
		end
	end
	
	return false;
end

function InstanceCounter.IsPlayerSavedToInstance(name, difficulty)
	for i = 1, GetNumSavedInstances() do
		local i_name,_,_, i_difficulty, i_locked = GetSavedInstanceInfo(i);
		
		if ((i_name == name) and (i_difficulty == difficulty) and (i_locked)) then return true end
	end
	
	return false;
end

function InstanceCounter.FlagInstancesForReset()
	self.ResetInstancesForCharacter(UnitName('player'))

	for groupindex = 1,MAX_PARTY_MEMBERS do
		local playername = UnitName('party' .. groupindex)
		if (playername ~= nil) then
			self.ResetInstancesForCharacter(playername)
		end
	end		
end

function InstanceCounter.ResetInstancesForCharacter(playername)
	for i = 1, # db.List do
		if (db.List[i].type == 'party' and db.List[i].character == playername) then
			if not db.List[i].reset then				
				db.List[i].reset_time = time();
				db.List[i].reset = true;
			end
		end
	end
end

function InstanceCounter.ResetInstanceByName(instance)
	for i = 1, # db.List do
		if (db.List[i].name == instance) then
			if not db.List[i].reset then			
				db.List[i].reset = true;	
				db.List[i].reset_time = time();
			end
		end
	end
end

function InstanceCounter.OnResetInstances()
	if (IsInInstance()) then return end
	if (not IsInGroup() or UnitIsGroupLeader('player')) then
		self.FlagInstancesForReset()
	end		
end


function InstanceCounter.SortInstances()
	table.sort(db.List, function(a, b) return a.time < b.time end);
end

function InstanceCounter.TimeRemaining(t)
	local t = 3600 - (time() - t);
	local neg = '';

	if t < 0 then 
		t = -t
		neg = '-'
	end

	return neg .. string.format("%.2d:%.2d", floor(t/60), t%60)
end



------ PRINT ------

function InstanceCounter.ClearOldAndPrint()
	if self.ClearOldInstances() and # db.List == 4 then
		print(prefix .. C.YELLOW .. L['OPEN_INSTANCES']);
	end
end

function InstanceCounter.PrintTimeUntilReset()
	if (# db.List > 0) then
		if (# db.List >= 5) then
			print(prefix .. C.YELLOW .. L['TIME_REMAINING'] .. self.TimeRemaining(db.List[1].last_seen));
		else
			print(prefix .. C.YELLOW .. L['ONLY_ENTERED'] .. C.GREEN .. # db.List .. L['THIS_HOUR']);
		end
	else
		print(prefix .. C.YELLOW .. L['NO_INSTANCES']);
	end
end

function InstanceCounter.PrintInstances()
	self.ClearOldInstances();
	
	if (# db.List > 0) then
		print(prefix .. C.YELLOW .. L['LIST_HEADERS']);
		for i = 1, # db.List do
			local i_color;
						
			if (db.List[i].reset) then
				i_color = C.RED
			else
				i_color = C.WHITE
			end
			print(C.WHITE .. db.List[i].character .. ' ' .. i_color .. db.List[i].name  .. C.WHITE .. ' ' .. self.TimeRemaining(db.List[i].last_seen));
		end
	else
		print(prefix .. C.YELLOW .. L['NO_INSTANCES']);
	end
end


function InstanceCounter.PrintInstancesToChat(chat, channel)
	self.ClearOldInstances();
	
	if (# db.List > 0) then
		SendChatMessage(L['LIST_HEADERS'], chat ,"Common", channel);
		for i = 1, # db.List do
			SendChatMessage(db.List[i].character .. ' - ' .. db.List[i].name  .. ' - ' .. self.TimeRemaining(db.List[i].last_seen), chat ,"Common", channel);
		end
	else
		SendChatMessage(L['NO_INSTANCES'], chat ,"Common", channel);
	end
end

function InstanceCounter.PrintOptions()
	print(prefix .. L['CMD_LONG'] .. C.RED .. L['CMD_CMD'] .. C.WHITE .. ' ' .. L['OR']  .. ' ' .. L['CMD_SHORT'] .. C.RED .. L['CMD_CMD']);
	print(prefix .. C.RED .. L['CMD']['PRINT']['CMD'] .. C.WHITE .. L['CMD']['PRINT']['DESCRIPTION']);
	print(prefix .. C.RED .. L['CMD']['RESET']['CMD'] .. C.WHITE .. L['CMD']['RESET']['DESCRIPTION']);
	print(prefix .. C.RED .. L['CMD']['TIME']['CMD'] .. C.WHITE .. L['CMD']['TIME']['DESCRIPTION']);
end

------


hooksecurefunc('ResetInstances', function(...)
	self.OnResetInstances();
end)

SlashCmdList['InstanceCounter'] = function(txt)
	local txt, arg1, arg2 = strsplit(" ", txt, 3)
	if txt == L['CMD']['CLEAR']['CMD'] then
		InstanceCounter.ClearInstances()
		print(prefix .. C.YELLOW .. L['LIST_CLEARED']);
	elseif txt == L['CMD']['PRINT']['CMD'] then
		InstanceCounter.PrintInstances()
	elseif txt == L['CMD']['RESET']['CMD'] then
		InstanceCounter.FlagInstancesForReset()
		print(prefix .. C.YELLOW .. L['MANUAL_RESET']);
	elseif txt == L['CMD']['TIME']['CMD'] then
		InstanceCounter.PrintTimeUntilReset()
	elseif txt == 'chat' then
		InstanceCounter.PrintInstancesToChat(arg1, arg2)
	else
		InstanceCounter.PrintOptions()
	end
end