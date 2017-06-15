[![Build Status](https://travis-ci.org/siffiejoe/lua-fx.svg?branch=master)](https://travis-ci.org/siffiejoe/lua-fx)

#                 FX -- Functional Experiments in Lua                #

##                           Introduction                           ##

Although Lua can be used for functional programming, it lacks the
usual toolset of functions that one needs for functional programming.
Some of those functions are easily implemented in Lua, others should
be implemented in C to avoid unnecessary performance loss. This
library contains a small core implemented in C that aims to make
functional (and in particular point-free or tacit) programming in Lua
easier. It mimics features from Clojure, and the [Ramda][1] Javascript
library, and will at some point be retitled to "Functional Extensions"
once it leaves experimental status.

  [1]: http://ramdajs.com/


##                             Concepts                             ##

###                Currying and Partial Application                ###

Currying is the process of transforming a function call taking `n`
arguments (e.g. `f( 1, 2, 3 )` into `n` function calls taking one
argument each (`f( 1 )( 2 )( 3 )`). Every function call except the
last just returns a new function that is a partially applied version
of the original one (i.e. the arguments provided so far are saved for
the final call). Currying and partial application are useful tools for
functional programming, because they provide an easy and syntactically
pleasing way to create specialized functions from generic ones.


###                           Transducers                          ###

[*Transducers*][2] (or *reducing function transformers*) are built on
the realization that `reduce` is the ultimate iteration function. It
works by calling a *reducing function* on each tuple/value during an
iteration, returning an updated state value that is then passed to the
next call of the reducing function and finally returned as the result
of `reduce`:

```lua
function aReducer( state, ... )
  -- ...
  return newState
end
```

A transducer is a function that takes a reducing function and returns
another reducing function:

```lua
function aTransducer( aReducer )
  return function( state, ... )
    if p( ... ) then
      return aReducer( state, f( ... ) )  -- pass (modified) data
    else
      return state  -- don't forward data
    end
  end
end
```

The new reducing function may forward the current iteration variables
(modified or as-is) to the old reducing function, or it may instead
return the state from the last call, basically ignoring the current
iteration step. The big advantage is that transducers only deal with
other reducing functions, and only the very last reducing function in
the chain needs to be aware of the contents of the state or where the
data is supposed to go. Thus, you can compose complex transformations
that are independent of the final output, and without intermediate
temporary copies of the iterated data structure.

  [2]: http://blog.cognitect.com/blog/2014/8/6/transducers-are-coming


###                            Sequences                           ###

Whenever this README mentions that a function operates on a sequence,
the usual Lua definition is assumed, i.e. a table for which the length
operator `#` is defined. However, if the table has a positive numeric
`.n` field (like in the table returned by `table.pack()`), that value
takes precedence, and the table may contain holes. Resulting tables
always have an `.n` field set.


##                             Reference                            ##

*   `fx.has( s ) ==> f`

    The `has` function takes a string of comma-separated field names
    and returns a function that checks for the existence of those
    fields in the given argument. The function returns `true` if all
    required fields are non-`nil`, and `false` otherwise. If a field
    name starts with a double underscore `"__"`, the field is looked
    up in the metatable instead. Some metamethods are assumed to be
    defined for certain Lua types (e.g. `__call` for functions).

    Field names may consist only of letters, digits, and `_`.
    Everything else (not just comma) is considered a field separator.
    This is an extended and optimized version of a [proposal][3] on
    the lua-l mailing list.

    Example:
    ```lua
    assert( fx.has"__index,__newindex"( t ) )
    -- raises an error if `t` is either not a table or doesn't
    -- have a metatable with __index and __newindex defined.
    assert( fx.has"__add,__sub"( n ) )
    -- works for numbers and objects with __add and __sub.
    ```


*   `fx.curry( n, f ) ==> f2`

    `fx.curry` creates a function that supports partial application
    simply by calling it with less than the expected number of
    arguments `n`. The result of such a partial application supports
    partial application the same way until all required arguments have
    been supplied, at which point the original function `f` is called
    with all collected argument values. The special `fx._` value can
    be used as an argument to reserve the slot for a later call.
    Reserved slots are filled from left to right, and the original
    function will not be called as long as there are placeholder
    values in the argument list.

    Example:
    ```lua
    local f = fx.curry( 3, print )
    -- the following expressions are all equivalent:
    f( 1, 2, 3 )
    f( 1 )( 2 )( 3 )
    f( 1, 2 )( 3 )
    f( 1 )( 2, 3 )
    f( fx._, 2 )( 1, 3 )
    f( fx._, 2 )( fx._, 3 )( 1 )
    ```


*   `fx._`

    `fx._` is a placeholder value that can be used to reserve a slot
    in the argument list during partial application, or to terminate a
    reduction early.


*   `fx.compose( f, ... ) ==> f2`

    `fx.compose` does function composition on a variable number of
    given functions. The resulting closure calls the functions from
    right to left, passing the return values as arguments to the next
    function.

    Example:
    ```lua
    local f = fx.compose( g, h, i )
    -- is equivalent to:
    local function f( ... )
      return g( h( i( ... ) ) )
    end
    ```

*   `fx.map( fun, t, ... ) ==> t2`

    `fx.map( fun, f ) ==> g`  (`f` and `g` are reducing functions)

    `fx.map` applies a function to all elements in a given sequence,
    returning a new table containing the results. Extra arguments
    passed to `fx.map` are passed as extra arguments to every call of
    `fun` to help avoid unnecessary closures. If the second argument
    to `fx.map` is a (reducing) function, a new reducing function is
    returned instead (thus, the partially applied `fx.map( fun )` acts
    as a transducer). The transducer is stateless unless `fun`
    maintains its own state.

    If `f`/`t` is not a function but defines a `__map@fx` metamethod
    in its metatable, `fx.map` delegates to this metamethod, passing
    all given arguments.

    The `fx.map` function is automatically curried with two expected
    arguments.


*   `fx.filter( pred, t, ... ) ==> t2`

    `fx.filter( pred, f ) ==> g`  (`f` and `g` are reducing functions)

    `fx.filter` applies a predicate `pred` to all elements in a given
    sequence and returns a new table containing all values for which
    the predicate returned a `true`ish value. Extra arguments passed
    to `fx.filter` are passed as extra arguments to every call of
    `pred` to help avoid unnecessary closures. If the second argument
    to `fx.filter` is a (reducing) function, a new reducing function
    is returned instead (the partially applied `fx.filter( pred )`
    acts as a transducer). The transducer is stateless unless `pred`
    maintains its own state.

    The `fx.filter` function is automatically curried with two
    expected arguments.


*   `fx.take( np, t, ... ) ==> t2`

    `fx.take( np, f ) ==> g`  (`f` and `g` are reducing functions)

    `fx.take` copies elements from the beginning of a sequence to a
    new table. The first paramater `np` may either be a number of
    elements to copy, or a predicate deciding when to stop copying
    (when the predicate returns a `false`y value for the first time).
    Extra arguments passed to `fx.take` are passed as extra arguments
    to every call of the predicate to help avoid unnecessary closures.
    If the second argument to `fx.take` is a (reducing) function, a
    new reducing function is returned instead (thus, the partially
    applied `fx.take( np )` acts as a transducer). The transducer is
    stateful, and the internal state is initialized when the
    transducer is called with the reducing function.

    The `fx.take` function is automatically curried with two expected
    arguments.


*   `fx.drop( np, t, ... ) ==> t2`

    `fx.drop( np, f ) ==> g`  (`f` and `g` are reducing functions)

    Like `fx.take` `fx.drop` also copies elements from a sequence to a
    new table, but it skips elements at the beginning. The first
    parameter `np` may either be a number of elements to skip, or a
    predicate deciding when to stop skipping (when the predicate
    returns a `false`y value for the first time). Extra arguments
    passed to `fx.drop` are passed as extra arguments to every call of
    the predicate to help avoid unnecessary closures. If the second
    argument to `fx.drop` is a (reducing) function, a new reducing
    function is returned instead (thus, the partially applied
    `fx.drop( np )` acts as a transducer). The transducer is stateful,
    and the internal state is initialized when the transducer is
    called with the reducing function.

    The `fx.drop` function is automatically curried with two expected
    arguments.


*   `fx.reduce( fun, init, f [, s [, var]] ) ==> val`

    `fx.reduce( fun, init, t, ... ) ==> val`

    The `fx.reduce` function calls the given "reducing function" `fun`
    for every tuple generated by the input iterator or every value
    from the input sequence, passing an additional `state` value as
    first argument. On the first call `state` is the same as `init`,
    on subsequent calls the `state` is the (first) result of the
    previous call to the reducing function. The result of the last
    call is returned from `fx.reduce` as `val`. If the reducing
    function returns `fx._` as the second return value (after the new
    `state` value), `fx.reduce` returns immediately with the new
    `state` as `val`.

    If the third argument is a function, `f`, `s`, and `var` are
    evaluated as iterator triplet and the function `fun` is called for
    every generated tuple `var_1, ..., var_n`, passing it after the
    `state` value.

    Otherwise the third argument is assumed to be a sequence(-like
    object) which is indexed using consecutive integers starting from
    `1` and ending at the value of the `n` field or the result of the
    length operator. The function `fun` is called for every value `v`:
    `fun( state, v, ... )`. Extra arguments to `fx.reduce` are passed
    as additional arguments to every reducing function call.

    `fx.reduce` can also be used to execute transducers, because a
    transducer, when called with a reducing function as argument,
    returns another reducing function.

    Example:

    ```lua
    local appending = fx.curry( 2, function( n, state, ... )
      state[ #state+1 ] = select( n, ... )
      return state
    end )
    local function double( v ) return 2*v end
    local xducer = fx.compose( fx.take( 5 ), fx.map( double ) )
    local t2 = fx.reduce( xducer( appending( 1 ) ), {}, t1 )
    ```

    This protocol of calling the transducer with the final reducing
    function right before passing it to `fx.reduce` is important for
    stateful transducers, because this is the time when the internal
    state (nothing to do with the `state` value) is initialized.

    Transducers can be composed like normal functions, but they take
    effect from left to right!

  [3]: http://lua-users.org/lists/lua-l/2013-05/msg00426.html


###                    Short Lambda Expressions                    ###

In many circumstances the functions above accept a short lambda
expression as a string instead of a real function. A short lambda
expression has the following format:
```lua
<arg> [,<arg>]* => [<expr> [, <expr>]*]
```
Vararg lists are supported as well. The string is compiled into a Lua
function on-the-fly using `lua_load()`, so the following two lines are
roughly equivalent:
```lua
local f = fx.compose( "x,y => x+y, x*y" )
local g = fx.compose( load( "return function(x,y) return x+y, x*y end" )() )
```
There is no caching/memoization going on, so be aware of the
performance implications if you do this in a tight loop. In fact, it
is recommended to use the short lambdas only as part of function
compositions (see also the `fx.glue` module below).

The following functions accept short lambda expressions: `fx.curry`,
`fx.compose`, `fx.map` (first argument), `fx.filter` (first argument),
`fx.take` (first argument), `fx.drop` (first argument), and
`fx.reduce` (first argument).


###                         Glue Functions                         ###

Unlike many functional programming languages, Lua supports multiple
return values. This makes composing functions more powerful, but it
also increases the chances of a mismatch between what one function
provides and the next one expects. Most common cases can (and should)
be handled with string lambdas, but for some akward situations the
`fx.glue` module provides glue functions that transform argument or
return value lists. It is similar in scope to the [`vararg`][4]
module, but since it is intended to be used with `compose`, the glue
functions in this module create closures that do the actual vararg
manipulation.

The following glue functions are provided:

*   `vmap( fun [, idx1 [, idx2]] ) ==> f`

    Returns a glue function that applies the function `fun` to each
    argument (between indices `idx1` and `idx2`, inclusively) and
    returns the results (the arguments outside of the specified range
    are passed unmodified). `fun`'s results are always adjusted to one
    return value for each call. `vmap` accepts short lambdas.

*   `vtransform( f1 [, f2 [, ..., fn]] ) ==> f`

    Returns a glue function that applies `f1` to `select( 1, ... )`
    to create the first return value, `f2` to `select( 2, ... )` to
    create the second return value, and so on. The last `fn` may
    return multiple values as usual. `vtransform` accepts short
    lambdas.

*   `vinsert( idx, v, ... ) ==> f`

    Returns a glue function that inserts all values `v, ...` before
    index `idx`. Using `nil` as `idx` will append to the vararg list.

*   `vreplace( idx, v, ... ) ==> f`

    Returns a glue function that replaces the arguments starting at
    index `idx` with the values `v, ...`.

*   `vreverse( [idx1 [, idx2]] ) ==> f`

    Returns a glue function that reverses all arguments between the
    indices `idx1` and `idx2` (inclusively). `idx1` defaults to `1`,
    and `idx2` defaults to `-1` (the last argument).

*   `vrotate( [idx [, n]] ) ==> f`

    Returns a glue function that right shifts all arguments starting
    at index `idx1` by `n` positions, reinserting the values that fall
    off at index `idx1`. `n` may be negative (to do a left shift) and
    defaults to `1`. `idx` defaults to `1` as well. (This is basically
    an interface to the `lua_rotate()` API function.)

  [4]: https://github.com/moteus/lua-vararg


##                           Installation                           ##

Compile the C source file `fx.c` into a shared library (`fx.so`, or
`fx.dll` on Windows) as usual for your platform and put it somewhere
into your Lua `package.cpath`.


##                             Contact                              ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                             License                              ##

**FX** is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    FX (c) 2013-2017 Philipp Janda

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


