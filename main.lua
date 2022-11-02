-- micro-run - Press F5 to run the current file, F12 to run make
-- Copyright 2020-2022 Tero Karvinen http://TeroKarvinen.com/micro
-- https://github.com/terokarvinen/micro-run

local config = import("micro/config")
local shell = import("micro/shell")
local micro = import("micro")
local os = import("os")

function init()
	config.MakeCommand("runit", runitCommand, config.NoComplete)
	config.TryBindKey("F5", "command:runit", true)

	config.MakeCommand("makeup", makeupCommand, config.NoComplete)
	config.TryBindKey("F12", "command:makeup", true)
end

function runitCommand(bp) -- bp BufPane
		bp:Save()

		local filename = bp.Buf.GetName(bp.Buf)
		local filetype = bp.Buf:FileType()
		local cmd = string.format("./%s", filename) -- does not support spaces in filename
		if filetype == "go" then
			if string.match(filename, "_test.go$") then
				cmd = "go test"
			else
				cmd = string.format("go run '%s'", filename)
			end
		elseif filetype == "python" then
			cmd = string.format("python3 '%s'", filename)
		elseif filetype == "html" then
			cmd = string.format("firefox-esr '%s'", filename)
		elseif filetype == "lua" then
			cmd = string.format("lua '%s'", filename)
		end

		shell.RunInteractiveShell(cmd, true, false)		
end

function makeup()
	-- Go up directories until a Makefile is found and run 'make'. 
	
	-- Caller is responsible for returning to original working directory,
	-- and micro will save the current file into the directory where 
	-- we are in. In this plugin, makeupCommand() implements returning 
	-- to original directory

	local err, pwd, prevdir
	for i = 1,20 do -- arbitrary number to make sure we exit one day
		-- pwd
		pwd, err = os.Getwd()
		if err ~= nil then
			micro.InfoBar():Message("Error: os.Getwd() failed!")
			return
		end
		micro.InfoBar():Message("Working directory is ", pwd)

		-- are we at root
		if pwd == prevdir then
			micro.InfoBar():Message("Makefile not found, looked at ", i, " directories.")
			return
		end
		prevdir = pwd

		-- check for file
		local dummy, err = os.Stat("Makefile")
		if err ~= nil then
			micro.InfoBar():Message("(not found in ", pwd, ")")
		else
			micro.InfoBar():Message("Running make, Found Makefile in ", pwd)
			local out = shell.RunInteractiveShell("make", true, true)
			return
		end

		-- cd ..
		local err = os.Chdir("..")
		if err ~= nil then
			micro.InfoBar():Message("Error: os.Chdir() failed!")
			return
		end
		
	end
	micro.InfoBar():Message("Warning: ran full 20 rounds but did not recognize root directory")
	return

end	

function makeupCommand(bp)
	bp:Save()
	micro.InfoBar():Message("makeup called")

	-- pwd
	local pwd, err = os.Getwd()
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Getwd() failed!")
		return
	end
	micro.InfoBar():Message("Working directory is ", pwd)
	local startDir = pwd

	makeup()

	-- finally, back to the directory where we were
	local err = os.Chdir(startDir)
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Chdir() failed!")
		return
	end
		
end
