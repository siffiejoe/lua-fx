package="fx"
version="scm-0"
source = {
  url = "git://github.com/siffiejoe/lua-fx.git",
}
description = {
  summary = "Functional Extensions (FX) for Lua",
  detailed = [[
    A small collection of essential tools for functional
    programming in Lua.
  ]],
  homepage = "https://github.com/siffiejoe/lua-fx/",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.5"
}
build = {
  type = "builtin",
  modules = {
    ["fx"]        = "fx.c",
    ["fx.optics"] = "fx/optics.lua",
--[[
    ["fx.functors"]          = "fx/functors.lua",
    ["fx.functors.const"]    = "fx/functors/const.lua",
    ["fx.functors.either"]   = "fx/functors/either.lua",
    ["fx.functors.endo"]     = "fx/functors/endo.lua",
    ["fx.functors.first"]    = "fx/functors/first.lua",
    ["fx.functors.free"]     = "fx/functors/free.lua",
    ["fx.functors.identity"] = "fx/functors/identity.lua",
    ["fx.functors.maybe"]    = "fx/functors/maybe.lua",
    ["fx.functors.table"]    = "fx/functors/table.lua",
--]]
  },
  install = {
    lua = {
      ["fx"]  = "fx.lua",
    }
  }
}

