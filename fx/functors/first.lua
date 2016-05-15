local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local assert_is_a = assert( F.assert_is_a )
local makeMonoid = assert( F.makeMonoid )
local _, Nothing = require( "fx.functors.maybe" )()


local First, Meta = makeMonoid( "First" )


setmetatable( First, {
  __call = function( _, v )
    assert_is_a( v, "Maybe" )
    return setmetatable( { v }, Meta )
  end
} )


function Meta:__tostring()
  return "First "..tostring( self[ 1 ] )
end


function First:get()
  return self[ 1 ]
end


function First.mempty()
  return First( Nothing )
end


function First:mappend( other )
  if self:get() == Nothing then
    return other
  else
    return self
  end
end


-- return type constructor
return function()
  return First
end

