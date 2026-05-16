local log = hs.logger.new("kvm-window-restore", "info")

local watchedKeyboardName = "Pterosphera"
local watchedVendorID = 0xfeed
local watchedProductID = 0x4242
local frameTolerance = 12
local evacuatedWindows = {}
local watcher = nil

local function copyFrame(frame)
  return {
    x = frame.x,
    y = frame.y,
    w = frame.w,
    h = frame.h,
  }
end

local function frameMatches(a, b, tolerance)
  if not a or not b then
    return false
  end

  local allowed = tolerance or frameTolerance

  return math.abs(a.x - b.x) <= allowed
    and math.abs(a.y - b.y) <= allowed
    and math.abs(a.w - b.w) <= allowed
    and math.abs(a.h - b.h) <= allowed
end

local function frameToString(frame)
  if not frame then
    return "<nil>"
  end

  return string.format("{x=%.1f, y=%.1f, w=%.1f, h=%.1f}", frame.x, frame.y, frame.w, frame.h)
end

local function usbEventSummary(data)
  if not data then
    return "<nil>"
  end

  return string.format(
    "eventType=%s productName=%s vendorName=%s vendorID=%s productID=%s",
    tostring(data.eventType),
    tostring(data.productName),
    tostring(data.vendorName),
    tostring(data.vendorID),
    tostring(data.productID)
  )
end

local function isWatchedKeyboardEvent(data)
  if not data then
    return false
  end

  if data.vendorID == watchedVendorID and data.productID == watchedProductID then
    return true
  end

  return data.productName == watchedKeyboardName
end

local function isBuiltinScreen(screen)
  if not screen then
    return false
  end

  local name = screen:name() or ""
  local lowered = string.lower(name)

  return lowered:find("built%-in", 1, false) ~= nil
    or lowered:find("retina", 1, false) ~= nil
    or lowered == "color lcd"
    or lowered:find("liquid retina", 1, false) ~= nil
end

local function getBuiltinScreen()
  for _, screen in ipairs(hs.screen.allScreens()) do
    if isBuiltinScreen(screen) then
      return screen
    end
  end

  return nil
end

local function getScreenByUUID(uuid)
  if not uuid then
    return nil
  end

  for _, screen in ipairs(hs.screen.allScreens()) do
    if screen:getUUID() == uuid then
      return screen
    end
  end

  return nil
end

local function getFallbackExternalScreen(builtinUUID)
  for _, screen in ipairs(hs.screen.allScreens()) do
    if screen:getUUID() ~= builtinUUID then
      return screen
    end
  end

  return nil
end

local function moveFrameBetweenScreens(sourceFrame, sourceScreen, targetScreen)
  local sourceBounds = sourceScreen:frame()
  local targetBounds = targetScreen:frame()

  local relativeX = 0
  local relativeY = 0

  if sourceBounds.w ~= 0 then
    relativeX = (sourceFrame.x - sourceBounds.x) / sourceBounds.w
  end

  if sourceBounds.h ~= 0 then
    relativeY = (sourceFrame.y - sourceBounds.y) / sourceBounds.h
  end

  local scaledWidth = sourceFrame.w
  local scaledHeight = sourceFrame.h

  if sourceBounds.w ~= 0 then
    scaledWidth = sourceFrame.w * (targetBounds.w / sourceBounds.w)
  end

  if sourceBounds.h ~= 0 then
    scaledHeight = sourceFrame.h * (targetBounds.h / sourceBounds.h)
  end

  scaledWidth = math.min(scaledWidth, targetBounds.w)
  scaledHeight = math.min(scaledHeight, targetBounds.h)

  local moved = {
    x = targetBounds.x + (relativeX * targetBounds.w),
    y = targetBounds.y + (relativeY * targetBounds.h),
    w = scaledWidth,
    h = scaledHeight,
  }

  moved.x = math.max(targetBounds.x, math.min(moved.x, targetBounds.x + targetBounds.w - moved.w))
  moved.y = math.max(targetBounds.y, math.min(moved.y, targetBounds.y + targetBounds.h - moved.h))

  return moved
end

local function isWindowCandidate(win)
  if not win or not win.id or not win.screen or not win.frame then
    return false
  end

  local id = win:id()
  local screen = win:screen()
  local frame = win:frame()

  if not id or not screen or not frame then
    return false
  end

  return frame.w > 0 and frame.h > 0
end

local function getStandardWindowSnapshot()
  local windows = {}

  for _, win in ipairs(hs.window.allWindows()) do
    if isWindowCandidate(win) then
      table.insert(windows, win)
    end
  end

  return windows
end

local function clearMissingWindows()
  for id, entry in pairs(evacuatedWindows) do
    local win = hs.window.get(id)
    if not win then
      log.i(string.format("Dropping stale window %s (%s)", tostring(id), entry.appName or "unknown"))
      evacuatedWindows[id] = nil
    end
  end
end

local function evacuateWindow(win, builtinScreen)
  local id = win:id()
  local sourceScreen = win:screen()

  if not id or not sourceScreen or isBuiltinScreen(sourceScreen) then
    return
  end

  local sourceFrame = win:frame()
  local evacuationFrame = moveFrameBetweenScreens(sourceFrame, sourceScreen, builtinScreen)

  local entry = {
    appName = win:application() and win:application():name() or "Unknown",
    title = win:title() or "",
    sourceFrame = copyFrame(sourceFrame),
    sourceScreenUUID = sourceScreen:getUUID(),
    sourceScreenName = sourceScreen:name(),
    evacuatedFrame = copyFrame(evacuationFrame),
    minimized = win:isMinimized(),
    fullscreen = win:isFullScreen(),
    capturedAt = os.time(),
  }

  if entry.minimized then
    win:unminimize()
  end

  if entry.fullscreen then
    log.w(string.format(
      "Window %s (%s) is fullscreen; restore may be imperfect",
      tostring(id),
      entry.appName
    ))
  end

  win:setFrame(evacuationFrame, 0)

  if entry.minimized then
    win:minimize()
  end

  evacuatedWindows[id] = entry

  log.i(string.format(
    "Evacuated %s (%s) from %s to built-in display: %s -> %s",
    tostring(id),
    entry.appName,
    entry.sourceScreenName or "external",
    frameToString(entry.sourceFrame),
    frameToString(entry.evacuatedFrame)
  ))
end

local function evacuateExternalWindows()
  clearMissingWindows()

  local builtinScreen = getBuiltinScreen()
  if not builtinScreen then
    log.e("No built-in display detected; skipping evacuation")
    return
  end

  local evacuatedCount = 0

  for _, win in ipairs(getStandardWindowSnapshot()) do
    local screen = win:screen()
    if screen and screen:getUUID() ~= builtinScreen:getUUID() then
      evacuateWindow(win, builtinScreen)
      evacuatedCount = evacuatedCount + 1
    end
  end

  log.i(string.format("Evacuation complete; moved %d windows", evacuatedCount))
end

local function restoreWindow(id, entry)
  local win = hs.window.get(id)
  if not win then
    log.i(string.format("Window %s is gone; skipping restore", tostring(id)))
    evacuatedWindows[id] = nil
    return
  end

  local currentFrame = win:frame()
  if not frameMatches(currentFrame, entry.evacuatedFrame, frameTolerance) then
    log.i(string.format(
      "Window %s (%s) changed while away; leaving it alone",
      tostring(id),
      entry.appName or "Unknown"
    ))
    evacuatedWindows[id] = nil
    return
  end

  local targetScreen = getScreenByUUID(entry.sourceScreenUUID)
  if not targetScreen then
    local builtinScreen = getBuiltinScreen()
    targetScreen = getFallbackExternalScreen(builtinScreen and builtinScreen:getUUID() or nil)
  end

  if not targetScreen then
    log.w(string.format("No external display available for window %s", tostring(id)))
    return
  end

  if entry.minimized then
    win:unminimize()
  end

  win:setFrame(entry.sourceFrame, 0)

  if entry.fullscreen then
    log.w(string.format(
      "Window %s (%s) was previously fullscreen; manual fullscreen re-entry may still be needed",
      tostring(id),
      entry.appName or "Unknown"
    ))
  end

  if entry.minimized then
    win:minimize()
  end

  log.i(string.format(
    "Restored %s (%s) to %s: %s",
    tostring(id),
    entry.appName or "Unknown",
    entry.sourceScreenName or targetScreen:name() or "external",
    frameToString(entry.sourceFrame)
  ))

  evacuatedWindows[id] = nil
end

local function restoreEvacuatedWindows()
  clearMissingWindows()

  local pending = 0
  for _ in pairs(evacuatedWindows) do
    pending = pending + 1
  end

  if pending == 0 then
    log.i("No evacuated windows to restore")
    return
  end

  for id, entry in pairs(evacuatedWindows) do
    restoreWindow(id, entry)
  end
end

local function handleUSBEvent(data)
  if not data then
    return
  end

  if isWatchedKeyboardEvent(data) then
    log.i(string.format("Observed watched USB event: %s", usbEventSummary(data)))
  elseif data.productName == watchedKeyboardName then
    log.i(string.format("Observed name-only USB event: %s", usbEventSummary(data)))
  else
    return
  end

  if data.eventType == "removed" then
    evacuateExternalWindows()
  elseif data.eventType == "added" then
    hs.timer.doAfter(1.0, restoreEvacuatedWindows)
  end
end

local function startWatcher()
  if watcher then
    watcher:stop()
  end

  watcher = hs.usb.watcher.new(handleUSBEvent)
  watcher:start()
end

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "R", function()
  hs.reload()
end)

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "E", function()
  evacuateExternalWindows()
end)

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "T", function()
  restoreEvacuatedWindows()
end)

startWatcher()
log.i("Loaded KVM window restore config")
