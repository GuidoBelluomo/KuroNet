# KuroNet
## Introduction
A Garry's Mod module that allows to send virtually infinitely long data (default limit is `16MB`, see more in the limitations section) by chunking it over the network, based on the original Garry's Mod net library. Functions for sending tables included, defaulting to the JSON functions that come with GMod. It's very easy to change this, and it's pretty straightforward.

Examples can be found at the beginning of the lua script.

This uses an indexing system to make sure messages arrive in order, in case it may for some reason happen they don't; essentially, all chunks carry an index value that is used to properly join everything later on.

## Use cases
- Some administrative plugins back in the day (probably still today) allowed admins to take screenshots from an user's game, and it was then streamed back to the admin for detecting any weird cheats. This was not possible without some kind of chunking, and this library can technically be used for the same purpose.
- Allowing users to type incredibly long text data, such as when editing a book for roleplay gamemodes or writing blog posts on internet-like gameplay systems.
- More? Yeah, probably more.

## Limitations
The max total amount of data (without accounting for "header" information of the chunk) that can be sent over in a single request is the value of the `maxBytes` variable * the `kNet.maxParts` variable, by default it's `64KB * 256`, meaning `16MB`

## Configuration
Minor edits of the lua file allow to change things such as the max bytes of each chunk, the server timeout, etc. Table encoding functions can be changed too.

```lua
local maxBytes = 2 ^ 16 -- Max bytes per data chunk, default to 64KB. Can be changed if GMod supports larger chunks, but at the time (11 years ago) and at the time of writing this, this was the maximum allowed. Feel free to check https://wiki.facepunch.com/gmod/net for any changes.
kNet.maxParts = 256 -- Max number of chunks that can be sent over. Can be changed, but this reduces the amount of actual data sent over the chunk. Should always be a power of two to maximize data efficiency.
kNet.maxNameLength = 64 -- Max length of the name key of the kNet request. Can be changed, but this reduces the amount of actual data sent over the chunk.
kNet.encode = util.TableToJSON -- Table encoding function, replace with pON or glON if needed.
kNet.decode = util.JSONToTable -- Table decoding function, replace with pON or glON if needed.
```

