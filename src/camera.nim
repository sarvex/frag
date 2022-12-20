import api, fuse

proc init(cam: ptr Camera; fovDeg: float32; viewport: Rectangle; fnear,
    ffar: float32) {.cdecl.} =
  cam.right = Float3fUnitX
  cam.up = Float3fUnitZ
  cam.forward = Float3fUnitY
  cam.pos = Float3fZero

  storeQuat(cam.quat.addr, identityQuat())
  cam.fov = fovDeg
  cam.fnear = fnear
  cam.ffar = ffar
  cam.viewport = viewport

proc calcFrustumPointsRange(cam: ptr Camera; frustum: ptr array[8, Float3f]; fNear,
    fFar: float32) {.cdecl.} =
  let
    fov = toRad(cam.fov)
    w = cam.viewport.xMax - cam.viewport.xMin
    h = cam.viewport.yMax - cam.viewport.yMin
    aspect = w / h

    xAxis = setVector(cam.right.x, cam.right.y, cam.right.z)
    yAxis = setVector(cam.up.x, cam.up.y, cam.up.z)
    zAxis = setVector(cam.forward.x, cam.forward.y, cam.forward.z)
    pos = setVector(cam.pos.x, cam.pos.y, cam.pos.z)

    nearPlaneH = tanScalar(fov * 0.5'f32) * fNear
    nearPlaneW = nearPlaneH * aspect

    farPlaneH = tanScalar(fov * 0.5'f32) * fFar
    farPlaneW = farPlaneH * aspect

    centerNear = addVector(mulVector(zAxis, fNear), pos)
    centerFar = addVector(mulVector(zAxis, fFar), pos)

    xNearScaled = mulVector(xAxis, nearPlaneW)
    xFarScaled = mulVector(xAxis, farPlaneW)
    yNearScaled = mulVector(yAxis, nearPlaneH)
    yFarScaled = mulVector(yAxis, farPlaneH)

  storeVector3(addr(frustum[0]), subVector(centerNear, addVector(xNearScaled, yNearScaled)))
  storeVector3(addr(frustum[1]), addVector(centerNear, subVector(xNearScaled, yNearScaled)))
  storeVector3(addr(frustum[2]), addVector(centerNear, addVector(xNearScaled, yNearScaled)))
  storeVector3(addr(frustum[3]), subVector(centerNear, subVector(xNearScaled, yNearScaled)))
  
  storeVector3(addr(frustum[4]), subVector(centerFar, addVector(xFarScaled, yFarScaled)))
  storeVector3(addr(frustum[5]), addVector(centerFar, subVector(xFarScaled, yFarScaled)))
  storeVector3(addr(frustum[6]), addVector(centerFar, addVector(xFarScaled, yFarScaled)))
  storeVector3(addr(frustum[7]), subVector(centerFar, subVector(xFarScaled, yFarScaled)))
  

proc perspective(cam: ptr Camera; proj: ptr Matrix4x4f) {.cdecl.} =
  assert(proj != nil)

  let
    w = cam.viewport.xMax - cam.viewport.xMin
    h = cam.viewport.yMax - cam.viewport.yMin

  proj[] = perspectiveFov(toRad(cam.fov), w / h, cam.fnear, cam.ffar,
      gfxApi.glFamily())

proc view(cam: ptr Camera; view: ptr Matrix4x4f) {.cdecl.} =
  assert(view != nil)

  let
    zAxis = cam.forward
    xAxis = cam.right
    yAxis = cam.up
    col0 = setVector(xAxis.x, xAxis.y, xAxis.z, -castScalar(dotVector3(
        setVector(xAxis.x, xAxis.y, xAxis.z), setVector(cam.pos.x, cam.pos.y, cam.pos.z))))
    col1 = setVector(yAxis.x, yAxis.y, yAxis.z, -castScalar(dotVector3(
        setVector(yAxis.x, yAxis.y, yAxis.z), setVector(cam.pos.x, cam.pos.y, cam.pos.z))))
    col2 = setVector(-zAxis.x, -zAxis.y, -zAxis.z, -castScalar(dotVector3(
        setVector(zAxis.x, zAxis.y, zAxis.z), setVector(cam.pos.x, cam.pos.y, cam.pos.z))))
    col3 = setVector(0.0'f32, 0.0'f32, 0.0'f32, 1.0'f32)

  view[] = setMatrix(col0, col1, col2, col3)

proc lookAt(cam: ptr Camera; pos, target, up: Float3f) =
  storeVector3(cam.forward.addr, normVector3(subVector(setVector(target.x,
      target.y, target.z), setVector(pos.x, pos.y, pos.z))))
  storeVector3(cam.right.addr, normVector3(crossVector3(setVector(cam.forward.x,
      cam.forward.y, cam.forward.z), setVector(up.x, up.y, up.z))))
  storeVector3(cam.up.addr, crossVector3(setVector(cam.right.x, cam.right.y,
      cam.right.z), setVector(cam.forward.x, cam.forward.y, cam.forward.z)))
  cam.pos = pos

  let m = setMatrix(
    setVector(cam.right.x, cam.right.y, cam.right.z, 0.0'f32),
    setVector(-cam.up.x, -cam.up.y, -cam.up.z, 0.0'f32),
    setVector(cam.forward.x, cam.forward.y, cam.forward.z, 0.0'f32),
    setVector(0.0'f32, 0.0'f32, 0.0'f32, 1.0'f32)
  )
  storeQuat(cam.quat.addr, quatFromMatrix(m.xAxis, m.yAxis, m.zAxis))

proc initFps(cam: ptr FpsCamera; fovDeg: float32; viewport: Rectangle; fnear,
    ffar: float32) {.cdecl.} =
  init(cam.cam.addr, fovDeg, viewport, fnear, ffar)
  cam.pitch = 0
  cam.yaw = cam.pitch

proc lookAtFps(cam: ptr FpsCamera; pos, target, up: Float3f) {.cdecl.} =
  lookAt(cam.cam.addr, pos, target, up)

  let euler = getQuatAxis(setQuat(cam.cam.quat.x, cam.cam.quat.y,
      cam.cam.quat.z, cam.cam.quat.w))
  cam.pitch = getVectorX(euler)
  cam.yaw = getVectorZ(euler)

cameraApi = CameraApi(
  perspective: perspective,
  view: view,
  calcFrustumPointsRange: calcFrustumPointsRange,
  initFps: initFps,
  lookAtFps: lookAtFps
)
