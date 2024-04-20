-- micro-run - Press F5 to run the current file, F12 to run make, F9 to make in background
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

	config.MakeCommand("makeupbg", makeupbgCommand, config.NoComplete)
	config.TryBindKey("F9", "command:makeupbg", true)	

end

function exists(path)
    local file = io.open(path,"r")
    if (file ~= nil) then
        io.close(file)
        return true
    else
        return false
    end
end

-- ### F5 runit ###

function runitCommand(bp) -- bp BufPane
	-- save & run the file we're editing
	-- choose run command according to filetype detected by micro
	bp:Save()
	
	local filename = bp.Buf.GetName(bp.Buf)
	local filetype = bp.Buf:FileType()

	if filetype == "c" then
		-- c is a special case
		-- c compilation only supported on Linux-like systems
		shell.RunInteractiveShell("clear", false, false)

		-- we must create the temporary file here 
		-- so that local attacker can't create a hostile one beforehand		
		-- RunInteractiveShell(input string, wait bool, getOutput bool) (string, error)
		cmd = string.format("mktemp '/tmp/micro-run-binary-XXXXXXXXXXX'", filename)
		tmpfile, err = shell.RunInteractiveShell(cmd, false, true)
		-- TODO: error handling

		shell.RunInteractiveShell("echo", false, false)
		
		-- compile to temporary file with unique(ish) tmp file name
		cmd = string.format("gcc '%s' -o '%s'", filename, tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- run temporary file
		cmd = string.format("'%s'", tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- remove temp file
		cmd = string.format("rm '%s'", tmpfile)
		shell.RunInteractiveShell(cmd, true, false)

		return -- early exit
	end

	if filetype == "rust" then -- filetype can be different from suffix
		-- Rust rs is handled like C.
		shell.RunInteractiveShell("clear", false, false)

		-- we must create the temporary file here 
		-- so that local attacker can't create a hostile one beforehand		
		-- RunInteractiveShell(input string, wait bool, getOutput bool) (string, error)
		cmd = string.format("mktemp '/tmp/micro-run-binary-XXXXXXXXXXX'", filename)
		tmpfile, err = shell.RunInteractiveShell(cmd, false, true)
		-- TODO: error handling

		shell.RunInteractiveShell("echo", false, false)
		
		-- compile to temporary file with unique(ish) tmp file name
		cmd = string.format("rustc '%s' -o '%s'", filename, tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- run temporary file
		cmd = string.format("'%s'", tmpfile)
		shell.RunInteractiveShell(cmd, false, false)

		-- remove temp file
		cmd = string.format("rm '%s'", tmpfile)
		shell.RunInteractiveShell(cmd, true, false)

		return -- early exit
	end


	local cmd = string.format("./%s", filename) -- does not support spaces in filename
	if filetype == "go" then
		if string.match(filename, "_test.go$") then
			cmd = "go test"
		else
			cmd = string.format("go run '%s'", filename)
		end
	elseif filetype == "python" then
		venv = exists(".venv/bin/python3")
		if venv == true then
			cmd = string.format(".venv/bin/python3 '%s'", filename)
		elseif venv == false then
			cmd = string.format("python3 '%s'", filename)
		end
	elseif filetype == "html" then
		cmd = string.format("firefox-esr '%s'", filename)
	elseif filetype == "lua" then
		cmd = string.format("lua '%s'", filename)
	elseif filetype == "shell" then
		cmd = string.format("bash '%s'", filename) -- we just assume the shell is bash
	end

	shell.RunInteractiveShell("clear", false, false)
	shell.RunInteractiveShell(cmd, true, false)		
end

-- ### F12 makeup ###

function makeupCommand(bp)
	-- run make in this or any higher directory, show output
	bp:Save()
	makeupWrapper(false)
end

-- ### F9 makeupbg ###

function makeupbgCommand(bp)
	-- run make in this or higher directory, in the background, hide most output
	bp:Save()
	makeupWrapper(true)	
end

function makeJobExit(out, args)
	-- makeJobExit is a callback function, called when shell.JobStart() is done running 'make'
	local out = string.sub(out, -79)
	out = string.gsub(out, "\n", " ")
	micro.InfoBar():Message("'make' done: ...", out)
end

-- ### both F9 makeupbg and F12 makeup ###

function makeupWrapper(bg)
	-- makeupWrapper returns us to original working directory after running make
	-- This must be used, because ctrl-S saving saves the current file in working directory
	-- If bg is true, run 'make' in the background
	micro.InfoBar():Message("makeup called")

	-- pwd
	local pwd, err = os.Getwd()
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Getwd() failed!")
		return
	end
	micro.InfoBar():Message("Working directory is ", pwd)
	local startDir = pwd

	-- make
	makeup(bg)

	-- finally, back to the directory where we were
	local err = os.Chdir(startDir)
	if err ~= nil then
		micro.InfoBar():Message("Error: os.Chdir() failed!")
		return
	end
end

function makeup(bg)
	-- Go up directories until a Makefile is found and run 'make'. 
	-- 'bg' means run in background, hiding most 'make' output. 
	
	-- Caller is responsible for returning to original working directory.
	-- Important, because micro will save the current file into the directory where 
	-- we are in. In this plugin, makeupWrapper() implements returning 
	-- to original directory. 

	local err, pwd, prevdir
	for i = 1,20 do -- arbitrary number to make sure we exit one day
		-- pwd
		pwd, err = os.Getwd()
		if err ~= nil then
			micro.InfoBar():Message("Error: os.Getwd() failed!")
			return
		end
		micro.InfoBar():Message("Working directory is ", pwd)

		-- are we at root directory?
		if pwd == prevdir then
			micro.InfoBar():Message("Makefile not found, looked at ", i, " directories.")
			return
		end
		prevdir = pwd

		-- check for file, run make
		local dummy, err = os.Stat("Makefile")
		if err ~= nil then
			micro.InfoBar():Message("(not found in ", pwd, ")")
		else
			if bg then
				micro.InfoBar():Message("Background running make, found Makefile in ", pwd)
				-- JobStart runs shell in other than working directory, so we must cd
				shell.JobStart("cd "..pwd.."; make", nil, nil, makeJobExit, nil)
			else
				micro.InfoBar():Message("Running make, found Makefile in ", pwd)
				-- RunInteractiveShell() uses the current working directory
				shell.RunInteractiveShell("clear", false, false)
				local out, err = shell.RunInteractiveShell("make", true, true)
			end
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

