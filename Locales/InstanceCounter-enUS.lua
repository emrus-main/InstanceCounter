InstanceCounterLocals = {}
local L = InstanceCounterLocals

L['CMD_LONG']		= '/InstanceCounter'
L['CMD_SHORT']		= '/ic'

L['NAME']			= 'InstanceCounter'
L['LIST_CLEARED']	= 'Instance list cleared.'
L['PRINT_DESCRIPTION']	= 'List of instance lockouts in the last hour'
L['PRINT_HEADERS']	= 'Character - Instance - Time Remaining'
L['PRINT_ROW']		= '%s - %s - %s'
L['MANUAL_RESET']	= 'Manual reset complete.'
L['NO_INSTANCES']	= 'You have not entered an instance in the last hour.'
L['ONLY_ENTERED']	= 'You have only entered %s instance(s) in the last hour'
L['OPEN_INSTANCES']	= 'You can now enter a new instance.'
L['TIME_REMAINING']	= 'You can enter a new instance in %s'
L['TOO_MANY_PREFIXES']	= "Error: Could not register addon communication, you won't receive updates from other player"
L['MESSAGE_NOT_SENT']	= 'Error: Could not send reset message to other players'

L['CMD_HEADER_DESC'] = '%s %s or %s %s'
L['CMD_DESC'] = '%s %s %s'
L['CMD_CMD']		= '<command>';
L['CMD'] = {
	['CLEAR']	= {['CMD'] = 'clear',	['ARGS'] = '',			['DESCRIPTION'] = 'Clears instance list. Only use in case of corruption'},
	['PRINT']	= {['CMD'] = 'print',	['ARGS'] = '',			['DESCRIPTION'] = 'Prints instance list.'},
	['RESET']	= {['CMD'] = 'reset',	['ARGS'] = '',			['DESCRIPTION']	= 'Manually flags all instances as reset and unavailable. Use this if instances where reset while you were offline'},
	['TIME']	= {['CMD'] = 'time',	['ARGS'] = '',			['DESCRIPTION'] = 'Displays the time remaining until you can enter another instance.'},
	['REPORT']	= {['CMD'] = 'report',	['ARGS'] = '<channel>',	['DESCRIPTION'] = 'Prints instance list to the <channel> specified. Valid values are: say, yell, party, raid'},
}

SLASH_InstanceCounter1 = L['CMD_LONG']
SLASH_InstanceCounter2 = L['CMD_SHORT']