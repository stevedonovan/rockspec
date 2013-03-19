rockspec
========

The [rockspec format](http://luarocks.org/en/Rockspec_format) as used by [LuaRocks](http://luarocks.org/)
provides a way to specify how to fetch and install a Lua package. 

`rockspec` is a command-line tool for generating rockspecs, much as Premake generates makefiles. It runs Lua
scripts called 'specfiles' and defines a DSL for specifying LuaRocks builds.

For example, the rockspec for this package was generated like so:

```sh
$ rockspec --git --depends penlight --script rockspec
```

See [full documentation](https://github.com/stevedonovan/blob/master/doc/readme.md)



