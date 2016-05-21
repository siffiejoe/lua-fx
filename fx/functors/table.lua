local assert = assert
local error = assert( error )
local select = assert( select )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )
local makeMonoid = assert( F.makeMonoid )


local Table, Meta = makeMonad( "Table" )
makeMonoid( "Table" )

function Meta:__newindex()
  error( "Table is supposed to be immutable", 2 )
end


setmetatable( Table, {
  __call = function( _, t )
    return setmetatable( t, Meta )
  end
} )


function Table:fmap( f )
  local n = #self
  if n < 1 then
    return self
  else
    local t = {}
    for i = 1, n do
      t[ i ] = f( self[ i ] )
    end
    return Table( t )
  end
end


function Table.pure( v )
  return Table{ v }
end


function Table:apply( f )
  assert( f.isTable, "Table expected" )
  local n, m = #self, #f
  if n < 1 then
    return self
  elseif m < 1 then
    return f
  else
    local t = {}
    for i = 1, m do
      for j = 1, n do
        t[ (i-1)*n+j ] = f[ i ]( self[ j ] )
      end
    end
    return Table( t )
  end
end


function Table:bind( f )
  local n = #self
  if n < 1 then
    return self
  else
    local t = {}
    for i = 1, n do
      local v = f( self[ i ] )
      local m = #v
      for j = 1, m do
        t[ (i-1)*m+j ] = v[ j ]
      end
    end
    return Table( t )
  end
end


function Table.mempty()
  return Table{}
end


function Table:mappend( other )
  assert( other.isTable, "Table expected" )
  local n, m = #self, #other
  if n < 1 then
    return other
  elseif m < 1 then
    return self
  else
    local t = {}
    for i = 1, n do
      t[ i ] = self[ i ]
    end
    for i = 1, m do
      t[ n+i ] = other[ i ]
    end
    return Table( t )
  end
end


-- return type constructor
return function()
  return Table
end

