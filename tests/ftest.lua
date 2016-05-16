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
local get2 = curry( 2, function( key, tab )
  local val = tab[ key ]
  if val == nil then
    return Left( "no field '"..tostring( key ).."'" )
  else
    return Right( val )
  end
end )

-- get first element of an array
local head, head2 = get( 1 ), get2( 1 )


local A = {}
local B = { addresses = {} }
local C = { addresses = { {}, {} } }
local D = {
  addresses = {
    { street = "Ratiborer Straße" },
    { street = "Sieglitzhofer Straße" },
  }
}


local firstAddressStreet = compose( map( string.upper, fx._ ),
                                    F.bind( get"street" ),
                                    F.bind( head ),
                                    F.bind( get"addresses" ) )
local firstAddressStreet2 = compose( F.fmap( string.upper ),
                                     F.bind( get2"street" ),
                                     F.bind( head2 ),
                                     F.bind( get2"addresses" ) )

print( firstAddressStreet( Just( A ) ) )
print( firstAddressStreet( Just( B ) ) )
print( firstAddressStreet( Just( C ) ) )
print( firstAddressStreet( Just( D ) ) )
-- with Either monad:
print( firstAddressStreet2( Right( A ) ) )
print( firstAddressStreet2( Right( B ) ) )
print( firstAddressStreet2( Right( C ) ) )
print( firstAddressStreet2( Right( D ) ) )

print( Just( C ) / get"addresses"
                 / head
                 / get"street"
                 % string.upper )
print( Just( D ) / get"addresses"
                 / head
                 / get"street"
                 % string.upper )

print( Const( "abc" ) % string.upper )
print( Identity( "abc" ) % string.upper )

local mul = curry( 2, function( a, b ) return a * b end )
local add = curry( 2, function( a, b ) return a + b end )

print( F.apply( Just( 3 ) % mul, Just( 5 ) ) )

local fl = List( mul( 2 ), add( 1 ) )
local nl = List.mappend( List( 3, 2, 1 ), List( 0 ) )
local rl = F.apply( fl, nl )
for _,h in rl:iterate() do io.write( h, "  " ) end
io.write( "\n" )

local ft = Table{ mul( 2 ), add( 1 ) }
local nt = Table.mappend( Table{ 3, 2, 1 }, Table{ 0 } )
local rt = F.apply( ft, nt )
for _,v in ipairs( rt ) do io.write( v, "  " ) end
io.write( "\n" )

