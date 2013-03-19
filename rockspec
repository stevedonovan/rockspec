#!/usr/bin/env lua
require 'pl'
local template = require 'pl.template'
local pretty = require 'pl.pretty'
local List = require 'pl.List'
local stringx = require 'pl.stringx'

class.PerPlatform()

function PerPlatform:_init(root,vtype,key,base)
    self.root = root
    self.vtype = vtype
    self.key = key
    self.basename = base
    self:set_platform(nil)
end

function PerPlatform:when (plat)
    self:set_platform(plat)
    return self
end

function PerPlatform:get_platform ()
    return self._plat
end

function PerPlatform:set_value (v)
    if self.vtype == 'array' then
        assert(type(v) == 'table','need a table value')
        for i,val in ipairs(v) do
            self.current[i] = val
        end
    elseif self.vtype == 'string' then
        assert(type(v) == 'string','need a string value')
        self.current[self.key] = v
    else
        error("cannot use set_value() for maps")
    end
end

function PerPlatform:set_platform (plat)
    self._plat = plat
    local root,basename,key = self.root,self.basename,self.key
    if plat then
        if not root.platforms then root.platforms = {} end
        root = root.platforms
    end
    if plat then
        if not root[plat] then root[plat] = {} end
        root = root[plat]
    end
    if basename then
        if not root[basename] then root[basename] = {} end
        self.current = root[basename]
    else
        self.current = root
    end
    if self.key and self.vtype ~= 'string' then --== 'map' then
        if not self.current[key] then self.current[key] = {} end
        self.current = self.current[key]
    end
    if not plat then
        self.master = self.current
    end
end

local function split_list (s)
    return List.split(s,'[%s,]+')
end

local function file_args (names)
    if type(names) ~= 'table' then
        return split_list(stringx.strip(names))
    else
        return List {names}
    end
end

build,dependencies,external_dependencies, platforms = {},{},{},{}

class.Module(PerPlatform)

function Module:_init (name,vtype)
    PerPlatform._init(self,build,vtype,name,'modules')
end

local function default_name (name,ext)
    ext = ext or '.lua'
    return name:gsub('%.','/')..'.'..ext
end

function Module:default_name (name)
    return default_name(name,self.extension)
end

function Module:rebase_file (file)
    if self.dir == '.' or file:match '^%./' then return file end -- explicitly relative
    return self.dir..'/'..file
end

class.LuaModule(Module)
LuaModule.extension = 'lua'

function LuaModule:_init (name,args)
    Module._init(self,name,'string')
    args = args or self:default_name(name)
    self:set_value(self:rebase_file(args))
end

class.CModule(Module)
CModule.extension = 'c'

function CModule:_init (name,args)
    Module._init(self,name,'map')
    args = file_args(args or self:default_name(name))
    self.current.sources = self:rebase(args)
end

function CModule:rebase (args)
    for i = 1,#args do
        args[i] = self:rebase_file(args[i])
    end
    return args
end

-- the following rather Java-esque machinery is necessary because the
-- module factory can be used in two ways:
-- (1) module.NAME ()
-- (2) module.PACKAGE.NAME()
-- So ModuleFactory has to return a callable object which makes modules
-- but is also indexable to capture the second pattern.
-- ModuleGen() acts as a proxy for ModuleFactory() which can collect any
-- package qualifiers
class.ModuleGen()

function ModuleGen:_init (kind,key)
    self.kind = kind
    self.key = key
end

-- Have to use rawget() because this class defines __index!
function ModuleGen:__call (args)
    local key = self.key
    if rawget(self,'package') then
        key =  key .. '.' .. self.package
    end
    local kind = self.kind
    if args == nil then
        return self.kind(key) --,key..'.'..kind.extension
    end
    if args:match '%*' then -- wildcard
        local files = dir.getfiles(kind.dir,args..'.'..kind.extension)
        for _,f in ipairs(files) do
            print (key,f)
            kind(key,f)
        end
    else
        return self.kind(key,args)
    end
end

function ModuleGen.__index(self,key)
    if rawget(self,'package') then
        self.package = self.package..'.'..key
    else
        self.package = key
    end
    return self
end

-- ModuleFactory makes modules, and knows what kind of module to make
-- and what directory to use for files
class.ModuleFactory()

function ModuleFactory.__index(self,key)
    return ModuleGen(self.kind,key)
end

function ModuleFactory:_init(kind)
    self.kind = kind
end

class.Install(PerPlatform)

function Install:_init (args,key)
    PerPlatform._init(self,build,'array',key,'install')
    self:set_value(file_args(args))
end

function bind2nd (f,y)
    return function(x) return f(x,y) end
end

local cfactory,lfactory = ModuleFactory(CModule), ModuleFactory(LuaModule)

local function set_directory (kind,default_dir)
    kind.dir = default_dir
    return function(dir)
        kind.dir = dir
    end
end

C = {
    module = cfactory,
    directory = set_directory(CModule,'.')
}

Lua = {
    module = lfactory,
    install = {
        script = bind2nd(Install,'bin'),
        conf = bind2nd(Install,'conf')
    },
    directory = set_directory(LuaModule,'.'),
}

-- LuaRocks optional builtin fields
for _,m in ipairs{'libraries','incdirs','defines','libdirs'} do
    CModule[m] = function(self,val)
        self.current[m] = file_args(val)
        return self
    end
end

function CModule:add (files)
    files = self:rebase(file_args(files))
    assert(self:get_platform(),'only makes sense per-platform')
    self.current.sources = List(self.master.sources) .. files
    return self
end

-- there is no top-level 'external' directive. Instead, it is per module
-- and the CModule class provides the functionality.
function CModule:external(lib)
    local libname = lib:upper()
    local ext = PerPlatform(external_dependencies,'map',libname)
    self.ext = ext
    self.exlib = libname
    ext:set_platform(self:get_platform())
    self.current.libraries = lib
    self:external_var ("libdir","LIBDIR")
    return self
end

function CModule:external_var (name,ext)
    self.current[name] = {'$('..self.exlib.."_"..ext..")"}
end

function CModule:include (file)
    self:external_var('incdirs','INCDIR')
    self.ext.current.header = file
    return self
end

function CModule:library (file)
    self.ext.current.library = file
    return self
end

-- the depends object can be called directly for unconditional dependencies,
-- but can be modified on a per-platform basis.
class.Depends(PerPlatform)

function Depends:_init ()
    PerPlatform._init(self,dependencies,'array')
end

function Depends:on (files)
    self:set_value(file_args(files))
    return self
end

function Depends:__call (files)
    return self:on (files)
end

depends = Depends()

local _package = package

function define_package(name,version,rversion)
    package_name = name
    package_version = version
    rockspec_version = rversion or "1"
end

local git_defs = {}

function git ()
    if not path.exists '.git' then
        utils.quit 'this is not the root of a Git repo'
    end
    local f = io.popen('git config -l')
    local cfg = config.read(f)
    f:close()
    if not next(cfg) then
        quit("unable to get Git configuration information")
    end
    pretty.dump(cfg)
    local remote = cfg.branch_master_remote
    if not remote then
        quit("no remote found for this repo")
    end
    print('('..remote..')')
    local url = cfg['remote_'..remote..'_url']
    if url:match '^git@' then
        url = url:gsub(':','/')
        url = url:gsub('git@','git://')
    end
    local name = path.splitext(path.basename(url))
    f = io.popen('git tag')
    local vs = f:read()
    f:close()
    define_package(name,vs)
    git_defs = {
        email = cfg.user_email,
        url = url
    }
    pretty.dump(git_defs)
    --os.exit()

end

function only(plats)
    supported_platforms = file_args(plats)
end

-- here's a nasty little global hack: modifying pairs() so that it tends to put
-- some keynames first.  Dubious in a general library, but part of the rules of
-- engagement for DSL creation ;)
local _pairs = pairs
local append = table.insert
local favoured = {type = true, sources = true}

function pairs(t)
    local keys = {}
    local idx
    for k in _pairs(t) do
        append(keys,k)
        if favoured[k] then idx = #keys end
    end
    if idx then
        keys[1],keys[idx] = keys[idx],keys[1]
    end
    local i = 0
    return function()
        i = i + 1
        return keys[i],t[keys[i]]
    end
end

defs = {}
local cfg_file = path.expanduser('~/.luarocks/rockspec.cfg')
if path.exists(cfg_file) then
    pretty.load(utils.readfile(cfg_file),defs)
end

text = pretty.write

local rockspec_template = [==[
package = "$(package_name)"
version = "$(package_version)-$(rockspec_version)"

source = {
  url = "$(URL)",
  $(BRANCH)
}

description = {
  summary = "one-line about $(package_name)",
  detailed = [[
   Some details about
   $(package_name)
  ]],
  license = "$(defs.license)",
  homepage = "$(defs.homepage)",
  maintainer = "$(defs.email)"
}

#if supported_platforms then
supported_platforms = $(text(supported_platforms))
#end

#if next(dependencies) then
dependencies = $(text(dependencies))
#end

#if next(external_dependencies) then
external_dependencies = $(text(external_dependencies))
#end

build = $(text(build))

]==]


rockspec = {}


function rockspec.write()
    package_fullname = package_name..'-'..package_version
    rockspec_name = package_fullname..'-'..rockspec_version..'.rockspec'
    defs.site = defs.site or "http://"..package_name..'.org/files'

    if git_defs.url then
        URL = git_defs.url
        BRANCH = 'tag="'..package_version..'"'
    else
        URL = defs.site..'/'..package_fullname..'.tar.gz'
    end

    defs.email = defs.email or git_defs.email or "you@your.org"
    defs.homepage = defs.homepage or "http://"..package_name..'.org'
    defs.license = defs.license or "MIT/X11"

    utils.writefile(rockspec_name,template.substitute(rockspec_template,_G))

    print(rockspec_name)
    return rockspec_name
end

package = define_package

local function parse_filename (f)
    local p,file = path.splitpath(f)
    local name = path.splitext(file)
    if path.extension(name) ~= '' then
        name = path.splitext(name)
    end
    local n,v = name:match('(.-)%-(.*)')
    if n then
        return name,v
    else
        return name,'1.0'
    end
end

local function empty (t)
    return not next(t)
end

local function filename (f)
    return path.splitext(path.basename(f))
end

local lapp = require 'pl.lapp'
local args = lapp [[
rockspec [flags] spec-script
    -d,--depends (default '') list of dependencies
    -s,--script  (default '') script to be installed
    -m,--module  (default '') Lua module(s) to be installed; can be a dir
    -c,--cmodule (default '') C files to be compiled as a Lua extension
    --make invoke 'luarocks make --local' afterwards
    -g,--git   get Git config data for user and repo information
    -v,--version (default '1.0') Version of package
    -b,--build dump out build section
]]

local specfile = args[1]
--pretty.dump(args)
if specfile and args.module == '' then
    local ok,err = pcall(dofile,specfile)
    if not ok then
        lapp.quit('specfile error '..err)
    end
    if not (package_name and package_version) then
        package_name, package_version = parse_filename(specfile)
        rockspec_version = '1'
    end
else
    if empty(dependencies) and args.depends ~= '' then
        dependencies = split_list(args.depends)
    end
    rockspec_version = '1'
    package_version = args.version
    if args.git then
        git()
    end
    if args.script ~= '' then
        Lua.install.script (args.script)
        package_name = args.script
    elseif args.module ~= '' then
        local mods, modlist
        if path.isdir(args.module) then -- implicit wildcard
            package_name = args.module
            mods = dir.getfiles(package_name,'*.lua')
            modlist = true
            mods = mods:map(filename)
            --print(mods)
        else
            mods = split_list(args.module)
            package_name = path.splitext(mods[1])
        end
        local L = Lua.module
        for m in mods:iter() do
            if modlist then
                L[package_name][m]()
            else
                L[m]()
            end
        end
    elseif args.cmodule ~= '' then
        local C = C.module
        package_name = args.cmodule
        C[args.cmodule]()    
    end
    if not package_name then
        lapp.quit 'please provide a specfile or either -s or -m'
    end
end
if build.modules then
    build.type = 'builtin'
else
    build.type = 'none'
end
if args.build then
    print(pretty.write(build))
else
    local rspec = rockspec.write()
    if args.make then
        os.execute('luarocks make --local '..rspec)
    end
end



