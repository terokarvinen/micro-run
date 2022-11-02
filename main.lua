-- micro-run - Press F5 to run the current file, a plugin for Micro editor 
-- Copyright 2020-2022 Tero Karvinen http://TeroKarvinen.com/micro
-- https://github.com/terokarvinen/micro-run

local config = import("micro/config")
local shell = import("micro/shell")

function init()
	config.MakeCommand("runit", runitCommand, config.NoComplete)
	config.TryBindKey("F5", "command:runit", true)
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

