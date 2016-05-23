#!/usr/bin/lua

package.path = "../?.lua;"..package.path
local fx = require( "fx" )()
local F = require( "fx.functors" )

local Just, Nothing = require( "fx.functors.maybe" )()
local Left, Right = require( "fx.functors.either" )()
local Const = require( "fx.functors.const" )()
local Identity = require( "fx.functors.identity" )()
local List, Nil = require( "fx.functors.list" )()
local Table = require( "fx.functors.table" )()
local liftF = require( "fx.functors.free" )


-- re-implementation of the Maybe monad using the Free monad:
local some, none, runOption
do
  local Some, SomeM = F.makeType( "Some" )
  local None, NoneM = F.makeType( "None" )
  Some.isOption, None.isOption = true, true

  local option_dispatch = {
    Some = function( self, f )
      return runOption( f( self[ 1 ] ) )
    end,
    None = function() return nil end
  }

  local free_option_dispatch = {
    Impure = function( self )
      local x, f = self:get()
      return x:switch( option_dispatch, f )
    end,
    Pure = function( self )
      return self:get()
    end
  }

  function some( v )
    return liftF( setmetatable( { v }, SomeM ) )
  end
  none = liftF( setmetatable( {}, NoneM ) )

  function runOption( o )
    return o:switch( free_option_dispatch )
  end
end


-- safe table indexing with Maybe monad
local get = curry( 2, function( key, tab )
  local val = tab[ key ]
  if val == nil then
    return Nothing
  else
    return Just( val )
  end
end )

-- same with Either monad (include error message)
local getE = curry( 2, function( key, tab )
  local val = tab[ key ]
  if val == nil then
    return Left( "no field '"..tostring( key ).."'" )
  else
    return Right( val )
  end
end )

-- use Option type derived from Free monad
local getO = curry( 2, function( key, tab )
  local val = tab[ key ]
  if val == nil then
    return none
  else
    return some( val )
  end
end )

-- get first element of an array
local head, headE, headO = get( 1 ), getE( 1 ), getO( 1 )


local A = {}
local B = { addresses = {} }
local C = { addresses = { {}, {} } }
local D = {
  addresses = {
    { street = "Ratiborer Straße" },
    { street = "Sieglitzhofer Straße" },
  }
}


local firstAddressStreet = compose( map( string.upper ),
                                    F.bind( get"street" ),
                                    F.bind( head ),
                                    F.bind( get"addresses" ) )
local firstAddressStreetE = compose( F.fmap( string.upper ),
                                     F.bind( getE"street" ),
                                     F.bind( headE ),
                                     F.bind( getE"addresses" ) )
local firstAddressStreetO = compose( F.fmap( string.upper ),
                                     F.bind( getO"street" ),
                                     F.bind( headO ),
                                     F.bind( getO"addresses" ) )

print( "using Maybe ..." )
print( "", firstAddressStreet( Just( A ) ) )
print( "", firstAddressStreet( Just( B ) ) )
print( "", firstAddressStreet( Just( C ) ) )
print( "", firstAddressStreet( Just( D ) ) )
print( "using Either ..." )
print( "", firstAddressStreetE( Right( A ) ) )
print( "", firstAddressStreetE( Right( B ) ) )
print( "", firstAddressStreetE( Right( C ) ) )
print( "", firstAddressStreetE( Right( D ) ) )
print( "using Option ..." )
print( "", runOption( firstAddressStreetO( some( A ) ) ) )
print( "", runOption( firstAddressStreetO( some( B ) ) ) )
print( "", runOption( firstAddressStreetO( some( C ) ) ) )
print( "", runOption( firstAddressStreetO( some( D ) ) ) )

print( "using operators for Maybe ..." )
print( "", Just( C ) / get"addresses"
                     / head
                     / get"street"
                     % string.upper )
print( "", Just( D ) / get"addresses"
                     / head
                     / get"street"
                     % string.upper )

print( "other stuff ..." )
print( Const( "abc" ) % string.upper )
print( Identity( "abc" ) % string.upper )

local mul = curry( 2, function( a, b ) return a * b end )
local add = curry( 2, function( a, b ) return a + b end )
local function add3( a, b, c ) return a + b + c end
local function add4( a, b, c, d ) return a + b + c + d end

print( F.apply( Just( 3 ) % mul, Just( 5 ) ) )
print( runOption( some( 3 ) % mul * some( 5 ) ) )
print( runOption( F.lift2( add, some( 3 ), some( 5 ) ) ) )
print( runOption( F.lift3( add3, some( 1 ), some( 2 ), some( 3 ) ) ) )
print( runOption( F.lift3( add3, some( 1 ), none, some( 3 ) ) ) )
print( F.lift4( add4, Just( 1 ), Just( 2 ), Just( 3 ), Just( 4 ) ) )
print( F.lift4( add4, Just( 1 ), Just( 2 ), Nothing, Just( 4 ) ) )

local fl = List( mul( 2 ), add( 1 ) )
local nl = List.mappend( List( 3, 2, 1 ), List( 0 ) )
local rl = F.apply( fl, nl )
for _,h in rl:iterate() do io.write( h, "  " ) end
io.write( "\n" )

local ft = Table{ mul( 2 ), add( 1 ) }
local nt = Table.mappend( Table{ 3, 2, 1 }, Table{ 0 } )
local rt = ft * nt
for _,v in ipairs( rt ) do io.write( v, "  " ) end
io.write( "\n" )

