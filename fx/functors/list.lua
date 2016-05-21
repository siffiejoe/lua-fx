local assert = assert
local select = assert( select )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )
local makeMonoid = assert( F.makeMonoid )


local List, Meta = makeMonad( "List" )
makeMonoid( "List" )
local Nil = setmetatable( {}, Meta ) -- the empty list


setmetatable( List, {
  __call = function( _, ... )
    local r = Nil
    for i = select( '#', ... ), 1, -1 do
      r = r:cons( (select( i, ... )) )
    end
    return r
  end
} )


function List:cons( v )
  return setmetatable( { v, self }, Meta )
end


function List:head()
  assert( self ~= Nil, "empty list" )
  return self[ 1 ]
end


function List:tail()
  assert( self ~= Nil, "empty list" )
  return self[ 2 ]
end


do
  local function list_iterator( _, var )
    return var[ 2 ], var[ 1 ]
  end

  function List:iterate()
    return list_iterator, true, self
  end

  function Meta:__pairs()
    return list_iterator, true, self
  end
end


function List:toarray()
  local t, n = {}, 1
  while self ~= Nil do
    t[ n ], n = self[ 1 ], n+1
  end
  return t, n-1
end


function List:fmap( f )
  local lst, newlst, lp = self, Nil
  if self ~= Nil then
    newlst = Nil:cons( f( lst[ 1 ] ) )
    lp, lst = newlst, lst[ 2 ]
    while lst ~= Nil do
      local c = Nil:cons( f( lst[ 1 ] ) )
      lp[ 2 ] = c
      lp, lst = c, lst[ 2 ]
    end
  end
  return newlst
end


function List.pure( v )
  return Nil:cons( v )
end


function List:apply( f )
  assert( f.isList, "List expected" )
  local lst, newlst, lp = self, Nil, nil
  while f ~= Nil do
    while lst ~= Nil do
      local c = Nil:cons( f[ 1 ]( lst[ 1 ] ) )
      if lp == nil then
        newlst = c
      else
        lp[ 2 ] = c
      end
      lp, lst = c, lst[ 2 ]
    end
    f, lst = f[ 2 ], self
  end
  return newlst
end


function List:bind( f )
  local lst, newlst, lp = self, Nil, nil
  while lst ~= Nil do
    local v = f( lst[ 1 ] )
    while v ~= Nil do
      local c = Nil:cons( v[ 1 ] )
      if lp == nil then
        newlst = c
      else
        lp[ 2 ] = c
      end
      lp, v = c, v[ 2 ]
    end
    lst = lst[ 2 ]
  end
  return newlst
end


function List.mempty()
  return Nil
end


function List:mappend( other )
  assert( other.isList, "List expected" )
  if self ~= Nil then
    local lst, newlst, lp = self, (Nil:cons( self[ 1 ] ))
    lp, lst = newlst, lst[ 2 ]
    repeat
      local c = Nil:cons( lst[ 1 ] )
      lp[ 2 ] = c
      lp, lst = c, lst[ 2 ]
    until lst == Nil
    lp[ 2 ] = other
    return newlst
  else
    return other
  end
end


-- return type constructor
return function()
  return List, Nil
end

