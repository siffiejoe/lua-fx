local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )


local Impure, IMeta = makeMonad( "Impure" )
local Pure, PMeta = makeMonad( "Pure" )
Impure.isFree, Pure.isFree = true, true


function IMeta:__tostring()
  return "Impure "..tostring( self[ 1 ] ).." f"
end
function PMeta:__tostring()
  return "Pure "..tostring( self[ 1 ] )
end


function Impure:get()
  return self[ 1 ], self[ 2 ]
end
function Pure:get()
  return self[ 1 ]
end


local function free_pure( v )
  local x = setmetatable( { v }, PMeta )
  return x
end
Impure.pure, Pure.pure = free_pure, free_pure


local free_fmap_dispatch = {
  Impure = function( self, f )
    local v, g = self[ 1 ], self[ 2 ]
    return setmetatable( { v, function( x )
      return g( x ):map( f )
    end }, IMeta )
  end,
  Pure = function( self, f )
    return free_pure( f( self[ 1 ] ) )
  end
}

local function free_fmap( self, f )
  return self:switch( free_fmap_dispatch, f )
end
Impure.map, Pure.map = free_fmap, free_fmap


local free_apply_dispatch = {
  Impure = function( self, x )
    local f, g = self[ 1 ], self[ 2 ]
    return setmetatable( { f, function( y )
      return x:apply( g( y ) )
    end }, IMeta )
  end,
  Pure = function( self, x )
    return x:map( self[ 1 ] )
  end,
}

local function free_apply( self, f )
  assert( f.isFree, "Free monad expected" )
  return f:switch( free_apply_dispatch, self )
end
Impure.apply, Pure.apply = free_apply, free_apply


local free_bind_dispatch = {
  Impure = function( self, f )
    local v, g = self[ 1 ], self[ 2 ]
    return setmetatable( { v, function( x )
      return g( x ):bind( f )
    end }, IMeta )
  end,
  Pure = function( self, f )
    return f( self[ 1 ] )
  end
}

local function free_bind( self, f )
  return self:switch( free_bind_dispatch, f )
end
Impure.bind, Pure.bind = free_bind, free_bind


-- return type constructor
return function( x )
  return setmetatable( { x, free_pure }, IMeta )
end

