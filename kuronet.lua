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

local maxBytes = 2 ^ 16

kuronet = {}
kuronet.messages = {}
kuronet.messages.strings = {}
kuronet.messages.tables = {}
kuronet.messages.strings.data = {}
kuronet.messages.tables.data = {}
kuronet.messages.strings.callbacks = {}
kuronet.messages.tables.callbacks = {}
kuronet.maxParts = 8
kuronet.maxNameLength = 6
kuronet.maxLength = maxBytes - (2 ^ kuronet.maxParts) * 2 - (2 ^ kuronet.maxNameLength) - 1 - 10

function kuronet.CheckName(name)
	if #name > 2 ^ kuronet.maxNameLength then
		ErrorNoHalt("Message: '"..name.."' has a too long name.")
		return false
	end
	return true
end

function kuronet.ReceiveString(name, func)
	if !kuronet.CheckName(name) then return end;

	kuronet.messages.strings.data[name] = {}
	kuronet.messages.strings.callbacks[name] = func
end

function kuronet.ReceiveTable(name, func)
	if !kuronet.CheckName(name) then return end;

	kuronet.messages.tables.data[name] = {}
	kuronet.messages.tables.callbacks[name] = func
end

if SERVER then
	net.Receive("kuronet_string", function(ply, length)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()

		kuronet.messages.strings.data[name][partIndex] = partText

		local complete = net.ReadUInt(8) == #kuronet.messages.strings.data[name]

		if complete then
			kuronet.messages.strings.callbacks[name](ply, length, table.concat(kuronet.messages.strings.data[name], ""))
			kuronet.messages.strings.data[name] = {}
		end
	end)

	net.Receive("kuronet_table", function(ply, length)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()

		kuronet.messages.tables.data[name][partIndex] = partText

		local complete = net.ReadUInt(8) == #kuronet.messages.tables.data[name]

		if complete then
			kuronet.messages.tables.callbacks[name](ply, length, pon.decode(table.concat(kuronet.messages.tables.data[name], "")))
			kuronet.messages.tables.data[name] = {}
		end
	end)
else
	net.Receive("kuronet_string", function(length)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()
		
		kuronet.messages.strings.data[name][partIndex] = partText

		local complete = net.ReadUInt(8) == #kuronet.messages.strings.data[name]

		if complete then
			kuronet.messages.strings.callbacks[name](length, table.concat(kuronet.messages.strings.data[name], ""))
			kuronet.messages.strings.data[name] = {}
		end
	end)

	net.Receive("kuronet_table", function(length)
		local name = net.ReadString()
		local partIndex = net.ReadUInt(8)
		local partText = net.ReadString()

		kuronet.messages.tables.data[name][partIndex] = partText

		local complete = net.ReadUInt(8) == #kuronet.messages.tables.data[name]

		if complete then
			kuronet.messages.tables.callbacks[name](length, pon.decode(table.concat(kuronet.messages.tables.data[name], "")))
			kuronet.messages.tables.data[name] = {}
		end
	end)
end

if SERVER then
	util.AddNetworkString("kuronet_string")
	util.AddNetworkString("kuronet_table")

	function kuronet.SendString(name, ply, str)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_string")
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

	function kuronet.SendStringOmit(ply, str)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_string")
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendOmit(ply)
		end
	end

	function kuronet.SendTable(ply, tbl)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_table")
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

	function kuronet.SendTableOmit(ply, tbl)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
		  if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_table")
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendOmit(ply)
		end
	end
else
	function kuronet.SendString(str)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_string")
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendToServer()
		end
	end

	function kuronet.SendTable(tbl)
		if !kuronet.CheckName(name) then return end;

		local part
		local maxLength = kuronet.maxLength
		local str = pon.encode(tbl)
		local strLen = #str
		local parts = math.ceil(strLen / maxLength)

		for i = 1, parts do
			part = string.sub(str, 1, math.Clamp(strLen, 1, maxLength))
			if strLen > maxLength then
				str = string.sub(str, maxLength + 1)
			end
			net.Start("kuronet_table")
				net.WriteString(name)
				net.WriteUInt(i, 8)
				net.WriteString(part)
				net.WriteUInt(parts, 8)
			net.SendToServer()
		end
	end
end
