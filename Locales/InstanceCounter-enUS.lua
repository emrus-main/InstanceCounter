InstanceCounterLocals = {}
local L = InstanceCounterLocals;

L['CMD_LONG']		= '/InstanceCounter';
L['CMD_SHORT']		= '/ic';



L['NAME']			= 'InstanceCounter'
L['LIST_CLEARED']	= 'Database cleared.';
L['LIST_HEADERS']	= 'Character Instance Time Remaining';
L['MANUAL_RESET']	= 'Manual reset complete.';
L['NO_INSTANCES']	= 'You have not entered an instance in the last hour.';
L['ONLY_ENTERED']	= 'You have only entered';
L['OPEN_INSTANCES']	= 'You can now enter a new instance.';
L['THIS_HOUR']		= ' instance/s this hour.';
L['TIME_REMAINING']	= 'Time remaining till you can enter another instance: ';
L['TOO_MANY_PREFIXES']	= "Error: Could not register addon communication, you won't receive updates from other player";
L['MESSAGE_NOT_SENT']	= 'Error: Could not send reset message to other players';
L['OR']				= 'or';

L['CMD'] = {
	['CLEAR']	= {['CMD'] = 'clear',	['DESCRIPTION'] = ' Clears instance list. Only use in case of corruption'},
	['PRINT']	= {['CMD'] = 'print',	['DESCRIPTION'] = ' Prints the instance list.'},
	['RESET']	= {['CMD'] = 'reset',	['DESCRIPTION']	= ' Manually flags all instances as reset and unavailable. Use this if instances where reset while you were offline'},
	['TIME']	= {['CMD'] = 'time',	['DESCRIPTION'] = ' Displays the time remaining until you can enter another instance.'},
}
L['CMD_CMD']		= ' [command]';


SLASH_InstanceCounter1 = L['CMD_LONG']
SLASH_InstanceCounter2 = L['CMD_SHORT'];