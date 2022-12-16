import std/[dynlib, os],
       api, fuse, logging, primer

type
  InjectedApi = object
    name: cstring
    version: uint32
    api: pointer

  PluginObject = object
    lib: pointer
    eventHandlerCb: EventHandlerCallback
    mainCb: MainCallback

  PluginData {.union.} = object
    plugin: Plugin
    obj: PluginObject

  PluginHandle = object
    data: PluginData

    info: PluginInfo
    filepath: array[MaxPath, char]

  PluginState = object
    plugins: seq[PluginHandle]
    pluginUpdateOrder: seq[int]
    pluginPath: string
    injected: seq[InjectedApi]

    loaded: bool

let nativeApis = [
  cast[pointer](coreApi.addr), pluginApi.addr, appApi.addr, gfxApi.addr,
      vfsApi.addr, assetApi.addr, cameraApi.addr
]

var ctx: PluginState

proc injectApi(name: cstring; version: uint32; api: pointer) {.cdecl.} =
  var apiIdx = -1
  for i in 0 ..< len(ctx.injected):
    if ctx.injected[i].name == name:
      apiIdx = i
      break

  if apiIdx == -1:
    add(ctx.injected, InjectedApi(
      name: nil,
      version: version,
      api: api
    ))
  else:
    ctx.injected[apiIdx].api = api

proc getApi(api: ApiType): pointer {.cdecl.} =
  result = nativeApis[api.int]

proc getApiByName(name: cstring; version: uint32): pointer {.cdecl.} =
  block outer:
    for i in 0 ..< len(ctx.injected):
      if name == ctx.injected[i].name:
        result = ctx.injected[i].api
        break outer

    result = nil

proc init*(pluginPath: cstring) =
  block outer:
    if not isNil(pluginPath) and bool(pluginPath[0]):
      ctx.pluginPath = $pluginPath
      normalizePath(ctx.pluginPath)
      if not dirExists(ctx.pluginPath):
        logError("plugin path '$#' is incorrect", ctx.pluginPath)
        # result = false
        break outer

proc loadAbs*(filepath: cstring; entry: bool) =
  var handle: PluginHandle
  handle.data.plugin.api = addr pluginApi

  var dll: pointer
  if not entry:
    discard
  else:
    dll = getAppModule()
    handle.info.name = appApi.name()

  handle.filepath.copyStr(filepath)

  unloadLib(dll)

  ctx.plugins.add(handle)
  ctx.pluginUpdateOrder.add(ctx.plugins.len() - 1)

proc load*(name: cstring): bool {.cdecl.} =
  assert(not ctx.loaded, "unable to load additional plugins after `initPlugins` has been invoked")

  let filepath = cstring(joinPath(ctx.pluginPath, $name) & ".dll")
  loadAbs(filepath, false)
  result = true

proc initPlugins*() =
  block outer:
    for i in 0 ..< ctx.pluginUpdateOrder.len():
      let
        idx = ctx.pluginUpdateOrder[i]
        handle = ctx.plugins[idx].addr

      if not openPlugin(handle.data.plugin.addr, cast[cstring](
          addr handle.filepath[0])).bool:
        logWarn("failed initialing plugin: $#", handle.filepath)
        break outer

      logDebug("initialized plugin!")
  
    ctx.loaded = true

proc update*() =
  block:
    for i in 0 ..< ctx.pluginUpdateOrder.len():
      let handle = ctx.plugins[ctx.pluginUpdateOrder[i]].addr
      assert updatePlugin(handle.data.plugin.addr, true) >= 0

proc shutdown*() =
  block:
    for i in 0 ..< ctx.pluginUpdateOrder.len():
      let handle = ctx.plugins[ctx.pluginUpdateOrder[i]].addr
      closePlugin(handle.data.plugin.addr)

pluginApi = PluginApi(
  load: load,
  injectApi: injectApi,
  getApi: getApi,
  getApiByName: getApiByName
)
