--[[
	The MIT License (MIT)

	Copyright (c) 2015 Guido Belluomo

	Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
	the Software, and to permit persons to whom the Software is furnished to do so,
	subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

-- EXAMPLES --
--[[
	if SERVER then
		function SendString()
			kNet.SendString("test_string", player.GetAll()[1], "Test")
		end

		kNet.ReceiveString("test_string", function(ply, length, str)
			file.Write("receivedmessage.txt", str)
		end)

		function SendTable()
			kNet.SendTable("test_table", nil, {1, 2, 3, 4, 5}) -- nil == net.Broadcast()
		end

		kNet.ReceiveTable("test_table", function(ply, length, tbl)
			for k, v in pairs (tbl) do
				print(v)
			end
		end)
	else
		concommand.Add("sendstring", function(ply)
			kNet.SendString("test_string", "Test")
		end)

		concommand.Add("sendtable", function(ply)
			kNet.SendTable("test_string", {1, 2, 3, 4, 5})
		end)

		kNet.ReceiveString("test_string", function(length, str)
			file.Write("receivedmessage.txt", str)
		end)

		kNet.ReceiveTable("test_table", function(length, tbl)
			for k, v in pairs (tbl) do
				print(v)
			end
		end)
	end
--]]
-- END EXAMPLES --

function math.ClampMin(val, min)
	return val > min and val or min
end

function table.iconcat(tbl, separator)
	local str = ""
	local filteredTbl = {}
	for k, v in pairs(tbl) do
		if (type(k) == "number") then
			filteredTbl[k] = v
		end
	end

	return table.concat(filteredTbl, separator)
end

local maxBytes = 2 ^ 16

kNet = {}
kNet.messages = {}
kNet.messages.strings = {}
kNet.messages.tables = {}
kNet.messages.strings.data = {}
kNet.messages.tables.data = {}
kNet.messages.strings.callbacks = {}
kNet.messages.tables.callbacks = {}
kNet.maxParts = 8
kNet.maxNameLength = 6
kNet.maxLength = maxBytes - math.ceil(math.ClampMin(kNet.maxParts / 8, 1)) * 2 - math.ceil(math.ClampMin(kNet.maxNameLength / 8, 1)) - 15 - 4 // - 15 is as a precaution, - 4 is for the 32bit uint of os.time()

function kNet.CheckName(name)
	if #name > 2 ^ kNet.maxNameLength then
		ErrorNoHalt("Message: '"..name.."' has a too long name.")
		return false
	end
	return true
end

function kNet.ReceiveString(name, func)
	if !kNet.CheckName(name) then return end;

	kNet.messages.strings.data[name] = {}
	kNet.messages.strings.callbacks[name] = func
end

function kNet.ReceiveTable(name, func)
	if !kNet.CheckName(name) then return end;

	kNet.messages.tables.data[name] = {}
	kNet.messages.tables.callbacks[name] = func
end

if SERVER then
	kNet.timeOut = 45
	kNet.cleanupInterval = 5
	kNet.nextCleanup = CurTime() + kNet.cleanupInterval

	function kNet.CleanupServer()
		local stringDataTbl = kNet.messages.strings.data
		local tablesDataTbl = kNet.messages.tables.data
		local timeOut = kNet.timeOut
		local time = os.time()

		for k, v in pairs (stringDataTbl) do // v = Name Table
			for k2, v2 in pairs (v) do // v2 = Player Table
				for k3, v3 in pairs (v2) do // v3 = Timestamp Table
					if !v3.completed and time >= v3.lastUpdate + timeOut then
						v2[k3] = nil
					end
				end

				if #v2 == 0 then
					v[k2] = nil
				end
			end
		end

		for k, v in pairs (tablesDataTbl) do // v = Name Table
			for k2, v2 in pairs (v) do // v2 = Player Table
				for k3, v3 in pairs (v2) do // v3 = Timestamp Table
					if !v3.completed and time >= v3.lastUpdate + timeOut then
						v2[k3] = nil
					end
				end

				if #v2 == 0 then
					v[k2] = nil
				end
			end
		end
	end

	hook.Add("Tick", "kNetCleanup", function()
		local curTime = CurTime()
		if curTime >= kNet.nextCleanup then
			kNet.CleanupServer()
			kNet.nextCleanup = curTime + kNet.cleanupInterval
		end
	end)
end

function kNet.DoStringCallbacks(name, length, ply)
	if SERVER then
		local baseTbl = kNet.messages.strings.data[name]
		local tbl = baseTbl[ply]
		local keys = table.SortByKey(tbl)
		for k, v in pairs(keys) do
			if tbl[v].complete then
				kNet.messages.strings.callbacks[name](ply, length, table.iconcat(tbl[v], ""))
				tbl[v] = nil
			else
				break
			end
		end

		if #tbl == 0 then
			tbl = nil
		end
	else
		local tbl = kNet.messages.strings.data[name]
		local keys = table.SortByKey(tbl)
		for k, v in pairs(keys) do
			if tbl[v].complete then
				kNet.messages.strings.callbacks[name](length, table.iconcat(tbl[v], ""))
				tbl[v] = nil
			else
				return
			end
		end
	end
end

function kNet.DoTableCallbacks(name, length, ply)
	if SERVER then
		local baseTbl = kNet.messages.tables.data[name]
		local tbl = baseTbl[ply]
		local keys = table.SortByKey(tbl)
		for k, v in pairs(keys) do
			if tbl[v].complete then
				kNet.messages.tables.callbacks[name](ply, length, pon.decode(table.iconcat(tbl[v], "")))
				tbl[v] = nil
			else
				break
			end
		end

		if #tbl == 0 then
			tbl = nil
		end
	else
		local tbl = kNet.messages.tables.data[name]
		local keys = table.SortByKey(tbl)
		for k, v in pairs(keys) do
			if tbl[v].complete then
				kNet.messages.tables.callbacks[name](length, pon.decode(table.iconcat(tbl[v], "")))
				tbl[v] = nil
			else
				return
			end
		end
	end
end

if SERVER then
	net.Receive("kNet_string", function(length, ply)
		local time = net.ReadUInt(32)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()
		local dataTbl = kNet.messages.strings.data[name]

		if !dataTbl[ply] then
			dataTbl[ply] = {}
		end

		if !dataTbl[ply][time] then
			dataTbl[ply][time] = {}
		end

		local dataTbl = dataTbl[ply]

		dataTbl[time][partIndex] = partText

		dataTbl[time].lastUpdate = os.time()

		local complete = net.ReadUInt(8) == #dataTbl[time]

		if complete then
			dataTbl[time].complete = true
			kNet.DoStringCallbacks(name, length, ply)
		end
	end)

	net.Receive("kNet_table", function(length, ply)
		local time = net.ReadUInt(32)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()
		local dataTbl = kNet.messages.tables.data[name]

		if !dataTbl[ply] then
			dataTbl[ply] = {}
		end

		if !dataTbl[ply][time] then
			dataTbl[ply][time] = {}
		end

		dataTbl = dataTbl[ply]

		dataTbl[time][partIndex] = partText

		dataTbl[time].lastUpdate = os.time()

		local complete = net.ReadUInt(8) == #dataTbl[time]

		if complete then
			dataTbl[time].complete = true
			kNet.DoStringCallbacks(name, length, ply)
		end
	end)
else
	net.Receive("kNet_string", function(ply, length)
		local time = net.ReadUInt(32)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()
		local dataTbl = kNet.messages.strings.data[name]

		if !dataTbl[time] then
			dataTbl[time] = {}
		end

		dataTbl[time][partIndex] = partText

		local complete = net.ReadUInt(8) == #dataTbl[time]

		if complete then
			dataTbl[time].complete = true
			kNet.DoStringCallbacks(name, length)
		end
	end)

	net.Receive("kNet_table", function(ply, length)
		local time = net.ReadUInt(32)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()
		local dataTbl = kNet.messages.tables.data[name]

		if !dataTbl[time] then
			dataTbl[time] = {}
		end

		dataTbl[time][partIndex] = partText

		local complete = net.ReadUInt(8) == #dataTbl[time]

		if complete then
			dataTbl[time].complete = true
			kNet.DoStringCallbacks(name, length)
		end
	end)
end

if SERVER then
	util.AddNetworkString("kNet_string")
	util.AddNetworkString("kNet_table")

	function kNet.SendString(name, ply, str)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_string")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			if (ply) then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end
	end

	function kNet.SendStringOmit(ply, str)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_string")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendOmit(ply)
		end
	end

	function kNet.SendTable(ply, tbl)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_table")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			if (ply) then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end
	end

	function kNet.SendTableOmit(ply, tbl)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_table")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendOmit(ply)
		end
	end
else
	function kNet.SendString(name, str)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_string")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendToServer()
		end
	end

	function kNet.SendTable(name, tbl)
		if !kNet.CheckName(name) then return end;

		local part
		local maxLength = kNet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)
		local time = os.time()

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kNet_table")
				net.WriteUInt(time, 32)
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendToServer()
		end
	end
end
