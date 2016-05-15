local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local assert_is_a = assert( F.assert_is_a )
local makeMonoid = assert( F.makeMonoid )


local Endo, Meta = makeMonoid( "Endo" )


setmetatable( Endo, {
  __call = function( _, v )
    return setmetatable( { v }, Meta )
  end
} )


function Meta:__tostring()
  return "Endo "..tostring( self[ 1 ] )
end


function Endo:get()
  return self[ 1 ]
end


local function id( ... ) return ... end

function Endo.mempty()
  return Endo( id )
end


function Endo:mappend( other )
  assert_is_a( other, "Endo" )
  local sf, of = self:get(), other:get()
  return Endo( function( ... )
    return sf( of( ... ) )
  end )
end


-- return type constructor
return function()
  return Endo
end

