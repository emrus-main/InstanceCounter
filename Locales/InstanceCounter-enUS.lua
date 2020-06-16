InstanceCounterLocals = {}
local L = InstanceCounterLocals

L['CMD_LONG']		= '/InstanceCounter'
L['CMD_SHORT']		= '/ic'

L['NAME']			= 'InstanceCounter'
L['LIST_CLEARED']	= 'Instance list cleared.'
L['PRINT_DESCRIPTION_HOUR']	= 'List of instance lockouts in the last hour'
L['PRINT_DESCRIPTION_DAY']	= 'List of instance lockouts in the last 24 hours'
L['PRINT_HEADERS']	= 'Character - Instance - Time Remaining'
L['PRINT_ROW']		= '%s - %s - %s'
L['MANUAL_RESET']	= 'Manual reset complete.'
L['OFFLINE_RESET']	= 'Your instance was detected be have been reset while you were offline'
L["INSTANCE_RESET"] = 'Instances has been reset'
L['NO_INSTANCES_HOUR']	= 'You have not entered an instance in the last hour.'
L['NO_INSTANCES_DAY']	= 'You have not entered an instance in the last 24 hours.'
L['ONLY_ENTERED']	= 'You have only entered %s instance(s) in the last hour'
L['OPEN_INSTANCES_HOUR']	= 'You can now enter a new instance.'
L['OPEN_INSTANCES_DAY']	= 'You are now only saved to %s instances for the last 24 hours.'
L['TIME_REMAINING_HOUR']	= 'You have entered %s instances in the last hour, next instance will reset in %s'
L['TIME_REMAINING_DAY']	= 'You have entered %s instances in the last day, next instance will reset in %s'
L['TOO_MANY_PREFIXES']	= "Error: Could not register addon communication, you won't receive updates from other player"
L['MESSAGE_NOT_SENT']	= 'Error: Could not send reset message to other players'

L['CMD_HEADER_DESC'] = '%s %s or %s %s'
L['CMD_DESC'] = '%s %s %s'
L['CMD_CMD']		= '<command>';
L['CMD'] = {
	['CLEAR']	= {['CMD'] = 'clear',	['ARGS'] = '',			['DESCRIPTION'] = 'Clears instance list. Only use in case of corruption'},
	['PRINT']	= {['CMD'] = 'print',	['ARGS'] = '',			['DESCRIPTION'] = 'Prints instance list for the last hour.'},
	['PRINTALL']= {['CMD'] = 'printall',['ARGS'] = '',			['DESCRIPTION'] = 'Prints instance list for the last 24 hours.'},
	['RESET']	= {['CMD'] = 'reset',	['ARGS'] = '',			['DESCRIPTION']	= 'Manually flags all instances as reset and unavailable. Use this if instances where reset while you were offline'},
	['TIME']	= {['CMD'] = 'time',	['ARGS'] = '',			['DESCRIPTION'] = 'Displays the time remaining until you can enter another instance.'},
	['REPORT']	= {['CMD'] = 'report',	['ARGS'] = '<channel>',	['DESCRIPTION'] = 'Prints instance list to the <channel> specified. Valid values are: say, yell, party, raid'},
	['REPORTALL']	= {['CMD'] = 'reportall',	['ARGS'] = '<channel>',	['DESCRIPTION'] = 'Prints instance list for the last 24 hours to the <channel> specified. Valid values are: say, yell, party, raid'},
}

SLASH_InstanceCounter1 = L['CMD_LONG']
SLASH_InstanceCounter2 = L['CMD_SHORT']