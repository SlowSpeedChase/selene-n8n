-- Open the newest version of SeleneChat
-- Searches for built app bundles and opens the most recently modified one

set projectPath to "/Users/chaseeasterling/selene-n8n/SeleneChat"
set defaultAppPath to projectPath & "/.build/release/SeleneChat.app"

tell application "System Events"
	-- Check if the default build location exists
	if exists folder defaultAppPath then
		do shell script "open " & quoted form of defaultAppPath
		return
	end if

	-- If not found in default location, search for any SeleneChat.app
	try
		set findResult to do shell script "find " & quoted form of projectPath & " -name 'SeleneChat.app' -type d 2>/dev/null | head -1"

		if findResult is not "" then
			do shell script "open " & quoted form of findResult
			return
		end if
	end try

	-- If no app found, offer to build it
	display dialog "SeleneChat.app not found. Would you like to build it now?" buttons {"Cancel", "Build"} default button "Build" with icon note

	if button returned of result is "Build" then
		-- Build the app
		tell application "Terminal"
			activate
			do script "cd " & quoted form of projectPath & " && ./build-app.sh && open .build/release/SeleneChat.app"
		end tell
	end if
end tell
