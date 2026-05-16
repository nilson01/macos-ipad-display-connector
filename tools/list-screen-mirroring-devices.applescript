property deviceIdentifierPrefix : "screen-mirroring-device-"

using terms from application "System Events"

on run
	my requireAccessibility()
	my dismissTransientUI()
	my openScreenMirroringPanel()
	delay 1
	
	set outputLines to {"Screen Mirroring devices:"}
	set foundAny to false
	
	tell application "System Events"
		tell application process "Control Center"
			try
				set candidateElements to UI elements of scroll area 1 of group 1 of window 1
				repeat with candidateElement in candidateElements
					set uiObject to contents of candidateElement
					set deviceIdentifier to my identifierFor(uiObject)
					if deviceIdentifier starts with deviceIdentifierPrefix then
						set foundAny to true
						set deviceName to my textAfterPrefix(deviceIdentifier, deviceIdentifierPrefix)
						if my toggleValue(uiObject) is 1 then
							set stateText to "[selected]"
						else
							set stateText to "[available]"
						end if
						set end of outputLines to "  " & stateText & " " & deviceName
					end if
				end repeat
			on error errMsg
				set end of outputLines to "  Could not inspect the Screen Mirroring list: " & errMsg
			end try
		end tell
	end tell
	
	if not foundAny then set end of outputLines to "  No devices were exposed through Accessibility."
	my dismissTransientUI()
	return my joinLines(outputLines)
end run

on requireAccessibility()
	tell application "System Events"
		if UI elements enabled is false then
			error "Accessibility automation is disabled. Enable it for Terminal, Shortcuts, Automator, or the launcher app in System Settings > Privacy & Security > Accessibility."
		end if
	end tell
end requireAccessibility

on openScreenMirroringPanel()
	set menuBarTarget to my findMenuBarItem({"Screen Mirroring"})
	if menuBarTarget is not missing value then
		my pressElementOrAncestor(menuBarTarget, 2)
		return
	end if
	
	set controlCenterItem to my findMenuBarItem({"Control Center"})
	if controlCenterItem is missing value then error "Could not find the Control Center menu bar item."
	my pressElementOrAncestor(controlCenterItem, 2)
	delay 0.8
	
	set mirrorButton to my findInControlCenterWindows({"Screen Mirroring"})
	if mirrorButton is missing value then error "Could not find Screen Mirroring inside Control Center."
	my pressElementOrAncestor(mirrorButton, 6)
end openScreenMirroringPanel

on findMenuBarItem(needles)
	tell application "System Events"
		tell application process "Control Center"
			try
				return my firstElementContainingAny(menu bar items of menu bar 1, needles)
			end try
		end tell
	end tell
	return missing value
end findMenuBarItem

on findInControlCenterWindows(needles)
	tell application "System Events"
		tell application process "Control Center"
			try
				return my firstElementContainingAny(windows, needles)
			end try
		end tell
	end tell
	return missing value
end findInControlCenterWindows

on firstElementContainingAny(theElements, needles)
	repeat with uiElement in theElements
		set uiObject to contents of uiElement
		if my elementContainsAny(uiObject, needles) then return uiObject
		try
			set childMatch to my firstElementContainingAny(UI elements of uiObject, needles)
			if childMatch is not missing value then return childMatch
		end try
	end repeat
	return missing value
end firstElementContainingAny

on elementContainsAny(uiObject, needles)
	set haystackText to my elementText(uiObject)
	repeat with needle in needles
		ignoring case
			if haystackText contains (needle as text) then return true
		end ignoring
	end repeat
	return false
end elementContainsAny

on elementText(uiObject)
	set textChunks to {}
	try
		if (name of uiObject) is not missing value then set end of textChunks to name of uiObject as text
	end try
	try
		if (description of uiObject) is not missing value then set end of textChunks to description of uiObject as text
	end try
	try
		set deviceIdentifier to my identifierFor(uiObject)
		if deviceIdentifier is not "" then set end of textChunks to deviceIdentifier
	end try
	return my joinWith(" ", textChunks)
end elementText

on identifierFor(uiObject)
	try
		set axIdentifier to value of attribute "AXIdentifier" of uiObject
		if axIdentifier is not missing value then return axIdentifier as text
	end try
	return ""
end identifierFor

on toggleValue(uiObject)
	try
		set rawValue to value of uiObject
		if class of rawValue is integer then return rawValue
	end try
	try
		set axValue to value of attribute "AXValue" of uiObject
		if class of axValue is integer then return axValue
	end try
	return 0
end toggleValue

on textAfterPrefix(theText, prefixText)
	if theText does not start with prefixText then return theText
	set prefixLength to length of prefixText
	return text (prefixLength + 1) thru -1 of theText
end textAfterPrefix

on pressElementOrAncestor(uiObject, maxHops)
	set currentObject to uiObject
	repeat with hopNumber from 0 to maxHops
		try
			perform action "AXPress" of currentObject
			return true
		end try
		try
			click currentObject
			return true
		end try
		try
			set currentObject to value of attribute "AXParent" of currentObject
		on error
			return false
		end try
	end repeat
	return false
end pressElementOrAncestor

on dismissTransientUI()
	try
		tell application "System Events"
			key code 53
			delay 0.2
			key code 53
		end tell
	end try
end dismissTransientUI

on joinWith(separatorText, theItems)
	set oldDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to separatorText
	set joinedText to theItems as text
	set AppleScript's text item delimiters to oldDelimiters
	return joinedText
end joinWith

on joinLines(theLines)
	return my joinWith(linefeed, theLines)
end joinLines

end using terms from
