local type = assert( type )
local setmetatable = assert( setmetatable )
local fx = require( "fx.core" )
local compose = assert( fx.compose )
local reduced = assert( fx._ )


local is_transformer = fx.has"__index,init,step,finish"
local is_callable = fx.has"__call"
local is_iterator = is_callable
local is_functor = fx.has"__index,map"

local shift = compose"_, ... => ..."
local complement = compose"x, ... => not x, ..."


-- the definition of sequence length used by this module
local function len( t )
  local n = t.n
  if type( n ) == "number" and n >= 0 then
    return n
  else
    return #t
  end
end


-- default init and finish implementation for stateless transducers
local transformer_meta = {
  __index = {
    init = function( self )
      return self.xform:init()
    end,
    finish = function( self, state )
      return self.xform:finish( state )
    end
  }
}



-- map
do
  local function map_step( self, state, ... )
    return self.xform:step( state, self.func( ... ) )
  end

  local function map_iterator_helper( func, var_1, ... )
    if var_1 ~= nil then
      return var_1, func( var_1, ... )
    end
  end

  local function map( func, obj, ... )
    func = compose( func ) -- handle string lambda
    if is_transformer( obj ) then
      return setmetatable( {
        xform = obj,
        func = func,
        step = map_step,
      }, transformer_meta )
    elseif is_functor( obj ) and is_callable( obj.map ) then
      return obj:map( func, ... )
    elseif is_iterator( obj ) then
      return function( s, var )
        return map_iterator_helper( func, obj( s, var ) )
      end, ...
    else -- assume it is a sequence
      local t = { n = len( obj ) }
      for i = 1, t.n do
        t[ i ] = func( obj[ i ], ... )
      end
      return t
    end
  end

  fx.map = fx.curry( 2, map )
end



-- filter
do
  local function filter_step( self, state, ... )
    if self.predicate( ... ) then
      return self.xform:step( state, ... )
    else
      return state
    end
  end

  local function filter_iterator_helper( predicate, f, s, var_1, ... )
    if var_1 ~= nil then
      if predicate( var_1, ... ) then
        return var_1, ...
      else
        return filter_iterator_helper( predicate, f, s, f( s, var_1 ) )
      end
    end
  end

  local function filter( predicate, obj, ... )
    predicate = compose( predicate ) -- handle string lambda
    if is_transformer( obj ) then
      return setmetatable( {
        xform = obj,
        predicate = predicate,
        step = filter_step,
      }, transformer_meta )
    elseif is_iterator( obj ) then
      return function( s, var )
        return filter_iterator_helper( predicate, obj, s, obj( s, var ) )
      end, ...
    else -- assume it is a sequence
      local j, t = 1, { n = 0 }
      for i = 1, len( obj ) do
        local value = obj[ i ]
        if predicate( value, ... ) then
          t[ j ], j = value, j + 1
        end
      end
      t.n = j - 1
      return t
    end
  end


  local function reject( predicate, ... )
    return filter( compose( complement, predicate ), ... )
  end

  fx.filter = fx.curry( 2, filter )
  fx.reject = fx.curry( 2, reject )
end



-- take
do
  local function take_n_init( self )
    self.count = self.num
    return self.xform:init()
  end

  local function take_n_step( self, state, ... )
    local cnt = self.count
    if cnt <= 0 then
      return state, reduced
    end
    self.count = cnt - 1
    return self.xform:step( state, ... )
  end

  local function take_while_step( self, state, ... )
    if not self.predicate( ... ) then
      return state, reduced
    end
    return self.xform:step( state, ... )
  end

  local function take_iterator_helper( predicate, var_1, ... )
    if var_1 ~= nil and predicate( var_1, ... ) then
      return var_1, ...
    end
  end

  local function take( np, obj, ... )
    if is_transformer( obj ) then
      if type( np ) == "number" then
        return setmetatable( {
          xform = obj,
          num = np,
          count = np,
          init = take_n_init,
          step = take_n_step,
        }, transformer_meta )
      else
        return setmetatable( {
          xform = obj,
          predicate = compose( np ),
          step = take_while_step,
        }, transformer_meta )
      end
    elseif is_iterator( obj ) then
      if type( np ) == "number" then
        local o_state, v = ...
        return function( s, var )
          local n = s[ 1 ]
          if n > 0 then
            s[ 1 ] = n - 1
            return obj( s[ 2 ], var )
          end
        end, { np, o_state }, v
      else
        np = compose( np ) -- handle string lambda
        return function( s, var )
          return take_iterator_helper( np, obj( s, var ) )
        end, ...
      end
    else -- assume it is a sequence
      local t, i, n = { n = 0 }, 1, len( obj )
      if type( np ) == "number" then
        while i <= n and i <= np do
          t[ i ], i = obj[ i ], i + 1
        end
      else
        np = compose( np ) -- handle string lambda
        while i <= n and np( obj[ i ], ... ) do
          t[ i ], i = obj[ i ], i + 1
        end
      end
      t.n = i - 1
      return t
    end
  end

  fx.take = fx.curry( 2, take )
end



-- drop
do
  local function drop_n_init( self )
    self.count = self.num
    return self.xform:init()
  end

  local function drop_while_init( self )
    self.test = self.predicate
    return self.xform:init()
  end

  local function drop_n_step( self, state, ... )
    local cnt = self.count
    if cnt > 0 then
      self.count = cnt - 1
      return state
    end
    return self.xform:step( state, ... )
  end

  local function drop_while_step( self, state, ... )
    local predicate = self.test
    if predicate and predicate( ... ) then
      return state
    end
    self.test = nil
    return self.xform:step( state, ... )
  end

  local function drop_iterator_helper( t, p, f, s, var_1, ... )
    if var_1 ~= nil and p( var_1, ... ) then
      return drop_iterator_helper( t, p, f, s, f( s, var_1 ) )
    end
    t[ 1 ] = nil
    return var_1, ...
  end

  local function drop( np, obj, ... )
    if is_transformer( obj ) then
      if type( np ) == "number" then
        return setmetatable( {
          xform = obj,
          num = np,
          count = np,
          init = drop_n_init,
          step = drop_n_step,
        }, transformer_meta )
      else
        return setmetatable( {
          xform = obj,
          predicate = compose( np ),
          test = nil,
          init = drop_while_init,
          step = drop_while_step,
        }, transformer_meta )
      end
    elseif is_iterator( obj ) then
      if type( np ) == "number" then
        local o_state, v = ...
        return function( s, var )
          local n, s2 = s[ 1 ], s[ 2 ]
          while n > 0 do
            var = obj( s2, var )
            if var == nil then n = 0 end
            n = n - 1
            s[ 1 ] = n
          end
          if n < 0 then return nil end
          return obj( s2, var )
        end, { np, o_state }, v
      else
        np = compose( np ) -- handle string lambda
        local o_state, v = ...
        return function( s, var )
          local p, s2 = s[ 1 ], s[ 2 ]
          if p then
            return drop_iterator_helper( s, p, obj, s2, obj( s2, var ) )
          end
          return obj( s2, var )
        end, { np, o_state }, v
      end
    else -- assume it is a sequence
      local t, i, n = { n = 0 }, 1, len( obj )
      if type( np ) == "number" then
        for j = np+1, n do
          t[ i ], i = obj[ j ], i + 1
        end
        t.n = i - 1
      else
        np = compose( np ) -- handle string lambda
        while i <= n and np( obj[ i ], ... ) do
          i = i + 1
        end
        local k = 1
        for j = i, n do
          t[ k ], k = obj[ j ], k + 1
        end
        t.n = k - 1
      end
      return t
    end
  end

  fx.drop = fx.curry( 2, drop )
end



-- reduce, transduce, into
do
  local function reduce_xf_helper( xf, val, f, s, var_1, ... )
    if var_1 ~= nil then
      val, control = xf:step( val, var_1, ... )
      if control ~= reduced then
        return reduce_xf_helper( xf, val, f, s, f( s, var_1 ) )
      end
    end
    return xf:finish( val )
  end

  local function reduce_f_helper( func, val, f, s, var_1, ... )
    if var_1 ~= nil then
      val, control = func( val, var_1, ... )
      if control ~= reduced then
        return reduce_f_helper( func, val, f, s, f( s, var_1 ) )
      end
    end
    return val
  end

  local function reduce( func, init, obj, ... )
    if is_iterator( obj ) then
      local s, var = ...
      if is_transformer( func ) then
        func:init()
        return reduce_xf_helper( func, init, obj, s, obj( s, var ) )
      else
        return reduce_f_helper( func, init, obj, s, obj( s, var ) )
      end
    else -- assume it is a sequence
      local control
      if is_transformer( func ) then
        func:init()
        for i = 1, len( obj ) do
          init, control = func:step( init, obj[ i ], ... )
          if control == reduced then break end
        end
        return func:finish( init )
      else
        func = compose( func ) -- handle string lambda
        for i = 1, len( obj ) do
          init, control = func( init, obj[ i ], ... )
          if control == reduced then break end
        end
        return init
      end
    end
  end


  local f2t_meta = {
    __index = {
      init = function() end,
      finish = function( _, state ) return state end,
    }
  }

  local function function2transformer( func )
    return setmetatable( {
      step = compose( func, shift )
    }, f2t_meta )
  end

  local function transduce( xform, red, ... )
    if not is_transformer( red ) then
      red = function2transformer( red )
    end
    return reduce( xform( red ), ... )
  end


  local append = function2transformer( function( t, v )
    local n = t.n + 1
    t.n, t[ n ] = n, v
    return t
  end )

  local function into( t, xform, ... )
    t.n = len( t )
    return reduce( xform( append ), t, ... )
  end

  fx.reduce = fx.curry( 3, reduce )
  fx.transduce = fx.curry( 3, transduce )
  fx.into = fx.curry( 3, into )
end



-- all, none
do
  local function all_init( self )
    self.all = true
    return self.xform:init()
  end

  local function all_finish( self, state )
    local xform = self.xform
    if self.all then
      state = xform:step( state, true )
    end
    return xform:finish( state )
  end

  local function all_step( self, state, ... )
    local xform, predicate = self.xform, self.predicate
    if not predicate( ... ) then
      self.all = false
      return xform:step( state, false ), reduced
    end
    return state
  end

  local all_meta = {
    __index = {
      init = all_init,
      step = all_step,
      finish = all_finish,
    }
  }

  local function all_iterator_helper( predicate, f, s, var_1, ... )
    if var_1 ~= nil then
      if not predicate( var_1, ... ) then
        return false
      end
      return all_iterator_helper( predicate, f, s, f( s, var_1 ) )
    end
    return true
  end

  local function all( predicate, obj, ... )
    predicate = compose( predicate ) -- handle string lambda
    if is_transformer( obj ) then
      return setmetatable( {
        xform = obj,
        predicate = predicate,
        all = true,
      }, all_meta )
    elseif is_iterator( obj ) then
      local s, var = ...
      return all_iterator_helper( predicate, obj, s, obj( s, var ) )
    else -- assume it is a sequence
      for i = 1, len( obj ) do
        if not predicate( obj[ i ], ... ) then
          return false
        end
      end
      return true
    end
  end


  local function none( predicate, ... )
    return all( compose( complement, predicate ), ... )
  end

  fx.all = fx.curry( 2, all )
  fx.none = fx.curry( 2, none )
end



-- any
do
  local function any_init( self )
    self.any = false
    return self.xform:init()
  end

  local function any_finish( self, state )
    local xform = self.xform
    if not self.any then
      state = xform:step( state, false )
    end
    return xform:finish( state )
  end

  local function any_step( self, state, ... )
    local xform, predicate = self.xform, self.predicate
    if predicate( ... ) then
      self.any = true
      return xform:step( state, true ), reduced
    end
    return state
  end

  local any_meta = {
    __index = {
      init = any_init,
      step = any_step,
      finish = any_finish,
    }
  }

  local function any_iterator_helper( predicate, f, s, var_1, ... )
    if var_1 ~= nil then
      if predicate( var_1, ... ) then
        return true
      end
      return any_iterator_helper( predicate, f, s, f( s, var_1 ) )
    end
    return false
  end

  local function any( predicate, obj, ... )
    predicate = compose( predicate ) -- handle string lambda
    if is_transformer( obj ) then
      return setmetatable( {
        xform = obj,
        predicate = predicate,
        any = false,
      }, any_meta )
    elseif is_iterator( obj ) then
      local s, var = ...
      return any_iterator_helper( predicate, obj, s, obj( s, var ) )
    else -- assume it is a sequence
      for i = 1, len( obj ) do
        if predicate( obj[ i ], ... ) then
          return true
        end
      end
      return false
    end
  end

  fx.any = fx.curry( 2, any )
end



-- return module table
return fx

