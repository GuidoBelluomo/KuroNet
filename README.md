# KuroNet
## Introduction
A Garry's Mod module that allows to send virtually infinitely long data over the network, based on the original Garry's Mod net library. Functions for sending tables included, defaulting to the JSON functions that come with GMod. It's very easy to change this, and it's pretty straightforward.

Examples can be found at the beginning of the lua script.

This uses an indexing system to make sure messages arrive in order, in case it may for some reason happen they don't; essentially, all chunks carry an index value that is used to properly join everything later on.

## Use cases
- Some administrative plugins back in the day (probably still today) allowed admins to take screenshots from an user's game, and it was then streamed back to the admin for detecting any weird cheats. This was not possible without some kind of chunking, and this library can technically be used for the same purpose.
- Allowing users to type incredibly long text data, such as when editing a book for roleplay gamemodes or writing blog posts on internet-like gameplay systems.
- More? Yeah, probably more.

## Configuration
Minor edits of the lua file allow to change things such as the max bytes of each chunk, the server timeout, etc. Other edits such as changing the data encoding functions are slightly more inventive but still possible.
