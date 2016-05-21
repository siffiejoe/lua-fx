local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )


local Identity, Meta = makeMonad( "Identity" )


setmetatable( Identity, {
  __call = function( _, v )
    return setmetatable( { v }, Meta )
  end
} )


function Meta:__tostring()
  return "Identity "..tostring( self[ 1 ] )
end


function Identity:get()
  return self[ 1 ]
end


function Identity:fmap( f )
  return Identity( f( self:get() ) )
end


function Identity.pure( v )
  return Identity( v )
end


function Identity:apply( f )
  assert( f.isIdentity, "Identity expected" )
  return Identity( f:get()( self:get() ) )
end


function Identity:bind( f )
  return f( self:get() )
end


-- return type constructor
return function()
  return Identity
end

