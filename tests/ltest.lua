#!/usr/bin/lua

package.path = "../?.lua;"..package.path
require( "fx" )()
require( "fx.lenses" )()
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
local add = curry( 2, function( a, b ) return a + b end )
local concat = curry( 2, function( a, b ) return a .. b end )
local function isfemale( _, t ) return t.sex == "f" end
local function isstring( _, v ) return type( v ) == "string" end
local function sendEmail( addr )
  print( "emailing", addr )
  return addr
end

-- create primitive lenses
local L = makeLenses( "friends", "email", "name", "sex", "foo" )

-- query/modify data structure:
p( "query name", view( L.name, user ) )
p( "query friends", view( L.friends, user ) )
p( "modify name", over( L.name, replace( "E", "***" ), user ) )
p( "set name", set( L.name, "Esmeralda", user ) )
p( "set friends to empty array", set( L.friends, {}, user ) )
L.firstFriend = compose( L.friends, L.indexed( 1 ) )
p( "query first friend", view( L.firstFriend, user ) )
p( "set first friend", set( L.firstFriend, newfriend, user ) )
L.firstFriendEmail = compose( L.firstFriend, L.email )
p( "change email of first friend", over( L.firstFriendEmail, string.upper, user ) )
L.friendsEmail = compose( L.friends, L.mapped, L.email )
local emailFriends = compose( concat( "Emailed friends of " ),
                              view( L.name ),
                              over( L.friendsEmail, sendEmail ) )
p( emailFriends( user ) )
p( "view all friends' email", view( L.friendsEmail, user ) )
p( "set all friends' email", set( L.friendsEmail, "none@anonymous.org", user ) )
L.mapped3 = compose( L.mapped, L.mapped, L.mapped )
p( "modify nested arrays", over( L.mapped3, add( 1 ), {{{ 1, 2 }, { 3, 4 }}} ) )
L.mapped2 = compose( L.mapped, L.mapped )
p( "view nested arrays", view( L.mapped2, { { 1 }, { 2 } } ) )
L.friendsFooFoo = compose( L.friends, L.mapped, L.foo, L.foo )
p( "view nonexisting (1)", view( L.friendsFooFoo, {} ) )
p( "view nonexisting (2)", view( L.friendsFooFoo, user ) )
p( "set nonexisting", set( L.friendsFooFoo, "x@y.z", user ) )
L.femaleFriends = compose( L.friends, L.filtered( isfemale ) )
L.femaleFriendsNames = compose( L.femaleFriends, L.name )
L.femaleFriendsSex = compose( L.femaleFriends, L.sex )
p( "view names of female friends", view( L.femaleFriendsNames, user ) )
p( "change sex of female friends", set( L.femaleFriendsSex, "m", user ) )
L.friendsStringProps = compose( L.friends, L.mapped, L.selected( isstring ) )
p( "view all friends' string properties", view( L.friendsStringProps, user ) )
p( "change all friends' string properties", over( L.friendsStringProps, string.upper, user ) )

p( "original user is unchanged", user )

