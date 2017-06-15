#!/usr/bin/lua

package.path = "../?.lua;"..package.path
require( "fx" )()
require( "fx.optics" )()
local serpent = require( "serpent" )


-- output nested data structures (allow optional label)
local function p( ... )
  local out, v
  if select( '#', ... ) > 1 then
    local l
    l, v = ...
    out = tostring( l )..": "..serpent.block( v )
  else
    v = ...
    out = serpent.block( v )
  end
  print( out )
  print( ("-"):rep( 70 ) )
  return v
end


-- the data structure we will work on
local user = {
  name = "Emily",
  age = 28,
  friends = {
    {
      name = "bob",
      age = 54,
      sex = "m",
      email = "bob@ross.net"
    },
    {
      name = "kendra",
      age = 19,
      sex = "f",
      email = "kendra@spacehog.org"
    },
    {
      name = "hank",
      age = 37,
      sex = "m",
      email = "hank@green.us"
    },
    {
      name = "ashley",
      age = 32,
      sex = "f",
      email = "ashley@email.org"
    }
  },
}
local newfriend = {
  name = "kelly", age = 41, sex = "f",
  email = "kelly@kapowski.net"
}

-- create helper functions
local replace = curry( 3, function( p, r, s )
  return (s:gsub( p, r ))
end )

-- create primitive lenses
local L = {
  friends = tableprism"friends",
  email = tableprism"email",
  name = tableprism"name",
}
L.firstFriend = compose( L.friends, tableprism( 1 ) )
L.firstFriendEmail = compose( L.firstFriend, L.email )

-- query/modify data structure:
print( ("-"):rep( 70 ) )
p( "query name", view( L.name, user ) )
p( "query friends", view( L.friends, user ) )
p( "modify name", over( L.name, replace( "E", "***" ), user ) )
p( "set name", set( L.name, "Esmeralda", user ) )
p( "set friends to empty array", set( L.friends, {}, user ) )
p( "query first friend", view( L.firstFriend, user ) )
p( "set first friend", set( L.firstFriend, newfriend, user ) )
p( "change email of first friend", over( L.firstFriendEmail, string.upper, user ) )
p( "change email of nonexistent friend", over( L.firstFriendEmail, string.upper, set( L.friends, {}, user ) ) )
p( "original user is unchanged", user )

