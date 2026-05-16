property unableNeedles : {"Unable to connect", "Could not connect", "couldn't connect", "failed to connect"}
property deviceIdentifierPrefix : "screen-mirroring-device-"
property stableSelectedSeconds : 8

using terms from application "System Events"

on run argv
	set targetName to my argumentOrDefault(argv, 1, "iPad")
	set maxAttempts to (my argumentOrDefault(argv, 2, "6")) as integer
	set retryDelay to (my argumentOrDefault(argv, 3, "5")) as integer
	set refreshControlCenter to my argumentOrDefault(argv, 4, "1")
	set connectWaitSeconds to (my argumentOrDefault(argv, 5, "35")) as integer
	
	my requireAccessibility()
	
	set lastProblem to "No attempt was made."
	repeat with attemptNumber from 1 to maxAttempts
		try
			my dismissUnableToConnectDialog()
			my logLine("Attempt " & attemptNumber & " of " & maxAttempts & ": opening Screen Mirroring.")
			my dismissTransientUI()
			my openScreenMirroringPanel()
			
			if my screenMirroringLooksConnected(targetName) then
				my logLine("Screen Mirroring already appears connected to " & targetName & ".")
				return "Already connected."
			end if
			
			set targetElement to my findDeviceElement(targetName)
			if targetElement is missing value then
				set lastProblem to "Did not find a visible Screen Mirroring target named '" & targetName & "'."
				my logLine(lastProblem)
			else
				my logLine("Found " & targetName & ". Pressing its Screen Mirroring row.")
				if not my pressElementOrAncestor(targetElement, 6) then
					error "Found '" & targetName & "', but could not press its row."
				end if
				
				set settleResult to my waitForConnection(targetName, connectWaitSeconds)
				if settleResult is "connected" then
					my logLine("Connection appears active.")
					return "Connected."
				else
					set lastProblem to settleResult
					my logLine(lastProblem)
				end if
			end if
		on error errMsg number errNum
			set lastProblem to errMsg
			my logLine("Attempt failed: " & errMsg)
		end try
		
		if attemptNumber < maxAttempts then
			my resetScreenMirroringUI(targetName, refreshControlCenter)
			delay retryDelay
		end if
	end repeat
	
	error "Failed after " & maxAttempts & " attempts. Last problem: " & lastProblem
end run

on argumentOrDefault(argv, itemNumber, defaultValue)
	if (count of argv) < itemNumber then return defaultValue
	return item itemNumber of argv
end argumentOrDefault

on requireAccessibility()
	tell application "System Events"
		if UI elements enabled is false then
			error "Accessibility automation is disabled. Enable it for the app that runs this script in System Settings > Privacy & Security > Accessibility."
		end if
	end tell
end requireAccessibility

on openScreenMirroringPanel()
	my waitForControlCenter(5)
	
	set menuBarTarget to my findMenuBarItem({"Screen Mirroring"})
	if menuBarTarget is not missing value then
		my pressElementOrAncestor(menuBarTarget, 2)
		delay 1
		return
	end if
	
	set controlCenterItem to my findMenuBarItem({"Control Center"})
	if controlCenterItem is missing value then error "Could not find the Control Center menu bar item."
	my pressElementOrAncestor(controlCenterItem, 2)
	delay 0.8
	
	set mirrorButton to my findInControlCenterWindows({"Screen Mirroring"})
	if mirrorButton is missing value then
		error "Opened Control Center, but could not find the Screen Mirroring control. Set Screen Mirroring to show in the menu bar for a more reliable target."
	end if
	
	my pressElementOrAncestor(mirrorButton, 6)
	delay 1
end openScreenMirroringPanel

on waitForControlCenter(timeoutSeconds)
	repeat with elapsedSeconds from 1 to timeoutSeconds
		tell application "System Events"
			if exists application process "Control Center" then return true
		end tell
		delay 1
	end repeat
	error "The Control Center process is not running."
end waitForControlCenter

on findMenuBarItem(needles)
	tell application "System Events"
		if not (exists application process "Control Center") then return missing value
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
		if not (exists application process "Control Center") then return missing value
		tell application process "Control Center"
			try
				return my firstElementContainingAny(windows, needles)
			end try
		end tell
	end tell
	return missing value
end findInControlCenterWindows

on findDeviceElement(targetName)
	set exactIdentifier to deviceIdentifierPrefix & targetName
	set targetElement to my findInControlCenterWindows({exactIdentifier})
	if targetElement is not missing value then return targetElement
	return my findInControlCenterWindows({targetName})
end findDeviceElement

on waitForConnection(targetName, timeoutSeconds)
	set selectedSince to 0
	
	repeat with elapsedSeconds from 1 to timeoutSeconds
		if my dismissUnableToConnectDialog() then return "macOS reported that it could not connect."
		
		if my screenMirroringLooksConnected(targetName) then
			if selectedSince is 0 then set selectedSince to elapsedSeconds
			if (elapsedSeconds - selectedSince) >= stableSelectedSeconds then return "connected"
		else
			set selectedSince to 0
		end if
		
		delay 1
	end repeat
	
	if my dismissUnableToConnectDialog() then return "macOS reported that it could not connect."
	if my screenMirroringLooksConnected(targetName) then return "connected"
	return "Timed out waiting for " & targetName & " to become the active Screen Mirroring target."
end waitForConnection

on screenMirroringLooksConnected(targetName)
	set targetElement to my findDeviceElement(targetName)
	if targetElement is missing value then return false
	return my elementToggleValue(targetElement) is 1
end screenMirroringLooksConnected

on dismissUnableToConnectDialog()
	set foundDialog to missing value
	tell application "System Events"
		repeat with processName in {"Control Center", "SystemUIServer", "Universal Control"}
			try
				if exists application process (processName as text) then
					tell application process (processName as text)
						set foundDialog to my firstElementContainingAny(windows, unableNeedles)
						if foundDialog is not missing value then exit repeat
					end tell
				end if
			end try
		end repeat
	end tell
	
	if foundDialog is missing value then return false
	
	my logLine("Detected an unable-to-connect dialog; dismissing it.")
	try
		set okButton to my firstElementContainingAny({foundDialog}, {"OK", "Done"})
		if okButton is not missing value then
			my pressElementOrAncestor(okButton, 4)
		else
			tell application "System Events" to key code 36
		end if
	on error
		tell application "System Events" to key code 36
	end try
	delay 0.5
	return true
end dismissUnableToConnectDialog

on resetScreenMirroringUI(targetName, refreshControlCenter)
	my dismissUnableToConnectDialog()
	try
		my openScreenMirroringPanel()
		my disconnectIfTargetSelected(targetName)
	end try
	my dismissTransientUI()
	
	if refreshControlCenter is "1" then
		try
			my logLine("Refreshing Control Center before retry.")
			tell application "Control Center" to quit
			delay 2
		end try
	end if
end resetScreenMirroringUI

on disconnectIfTargetSelected(targetName)
	set targetElement to my findDeviceElement(targetName)
	if targetElement is missing value then return false
	if my elementToggleValue(targetElement) is not 1 then return false
	
	my logLine("Target appears selected during recovery; pressing it to disconnect before retrying.")
	my pressElementOrAncestor(targetElement, 6)
	delay 2
	return true
end disconnectIfTargetSelected

on dismissTransientUI()
	try
		tell application "System Events"
			key code 53
			delay 0.2
			key code 53
		end tell
	end try
end dismissTransientUI

on firstElementContainingAny(theElements, needles)
	repeat with uiElement in theElements
		set uiObject to contents of uiElement
		if my elementContainsAny(uiObject, needles) then return uiObject
		
		try
			set childElements to UI elements of uiObject
			if (count of childElements) > 0 then
				set childMatch to my firstElementContainingAny(childElements, needles)
				if childMatch is not missing value then return childMatch
			end if
		end try
	end repeat
	return missing value
end firstElementContainingAny

on elementContainsAny(uiObject, needles)
	set haystackText to my elementText(uiObject)
	if haystackText is "" then return false
	
	repeat with needle in needles
		set needleText to needle as text
		ignoring case
			if haystackText contains needleText then return true
		end ignoring
	end repeat
	
	return false
end elementContainsAny

on elementText(uiObject)
	set oldDelimiters to AppleScript's text item delimiters
	set textChunks to {}
	
	try
		set elementName to name of uiObject
		if elementName is not missing value and elementName is not "" then set end of textChunks to elementName as text
	end try
	
	try
		set elementTitle to title of uiObject
		if elementTitle is not missing value and elementTitle is not "" then set end of textChunks to elementTitle as text
	end try
	
	try
		set elementDescription to description of uiObject
		if elementDescription is not missing value and elementDescription is not "" then set end of textChunks to elementDescription as text
	end try
	
	try
		set elementValue to value of uiObject
		if class of elementValue is text and elementValue is not "" then set end of textChunks to elementValue
	end try
	
	try
		set axDescription to value of attribute "AXDescription" of uiObject
		if axDescription is not missing value and axDescription is not "" then set end of textChunks to axDescription as text
	end try
	
	try
		set axIdentifier to value of attribute "AXIdentifier" of uiObject
		if axIdentifier is not missing value and axIdentifier is not "" then set end of textChunks to axIdentifier as text
	end try
	
	set AppleScript's text item delimiters to " "
	set joinedText to textChunks as text
	set AppleScript's text item delimiters to oldDelimiters
	return joinedText
end elementText

on elementToggleValue(uiObject)
	try
		set rawValue to value of uiObject
		if class of rawValue is integer then return rawValue
		if class of rawValue is boolean then
			if rawValue then return 1
			return 0
		end if
	end try
	
	try
		set axValue to value of attribute "AXValue" of uiObject
		if class of axValue is integer then return axValue
		if class of axValue is boolean then
			if axValue then return 1
			return 0
		end if
	end try
	
	return -1
end elementToggleValue

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

on logLine(messageText)
	log messageText
end logLine

end using terms from
