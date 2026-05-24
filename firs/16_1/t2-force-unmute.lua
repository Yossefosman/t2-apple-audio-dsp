-- Force T2 raw audio devices to be unmuted at full volume
-- This ensures the DSP has proper input/output levels
-- Also initializes DSP sink volume to default on first appearance
-- Based on Asahi Linux's asahi-limit-volume.lua

local config = ... or {}

seen_devices = {}
dsp_sink_handled = {}

local function parseParam(param, id)
  local route = param:parse()
  if route.pod_type == "Object" and route.object_id == id then
    return route.properties
  else
    return nil
  end
end

local function handleDevice(device)
  for p in device:iterate_params("Route") do
    local route = parseParam(p, "Route")
    if not route then
      goto skip_route
    end

    -- Handle both Speakers and BuiltinMic/Digital Mic
    local desc = route.description
    if desc ~= "Speakers" and desc ~= "Speaker" and desc ~= "BuiltinMic" and desc ~= "Digital Mic" then
      goto skip_route
    end

    local pr = route.props
    if pr and pr.properties then
      pr = pr.properties
    end

    if pr and (pr.channelVolumes == nil or pr.channelVolumes[1] ~= 1.0 or pr.mute == true) then
      local props = {
        "Spa:Pod:Object:Param:Props", "Route",
        mute = false,
        channelVolumes = Pod.Array({ "Spa:Float", 1.0 })
      }
      local param = Pod.Object {
        "Spa:Pod:Object:Param:Route", "Route",
        index = route.index,
        device = route.device,
        props = Pod.Object(props),
      }
      Log.info("Forcing route to unmuted full volume: " .. tostring(desc))
      device:set_param("Route", param)
    end
    ::skip_route::
  end
end

local default_vol = 0.75

local function setDspSinkVolume(node)
  local channelVols = { default_vol, default_vol }
  table.insert(channelVols, 1, "Spa:Float")
  local props = Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    volume = default_vol,
    channelVolumes = Pod.Array(channelVols),
  }
  Log.info("Setting DSP sink volume to " .. tostring(default_vol))
  node:set_param("Props", props)
end

local function checkAndSetVolume(node)
  for p in node:iterate_params("Props") do
    local props = parseParam(p, "Props")
    if props then
      local vol = props.volume
      Log.info("DSP sink Props: volume=" .. tostring(vol) .. " handled=" .. tostring(dsp_sink_handled[node["bound-id"]]))
      if dsp_sink_handled[node["bound-id"]] then
        return true
      end
      if vol == nil or vol > 0.99 then
        Log.info("DSP sink volume at max or unset (" .. tostring(vol) .. "), setting to " .. tostring(default_vol))
        setDspSinkVolume(node)
        return false
      else
        Log.info("DSP sink volume already set to " .. tostring(vol) .. ", marking handled")
        dsp_sink_handled[node["bound-id"]] = true
        return true
      end
    end
  end
  return nil
end

local function onDspSinkParams(node)
  local result = checkAndSetVolume(node)
  -- If Props wasn't available yet, we'll try again on next params-changed
end

local function handleDspSink(node)
  if dsp_sink_handled[node["bound-id"]] then
    return
  end
  node:connect("params-changed", onDspSinkParams)
  -- Also try to set immediately if possible
  checkAndSetVolume(node)
end

om = ObjectManager {
  Interest {
    type = "device",
    Constraint { "alsa.card_name", "equals", "Apple T2 Audio", type = "pw" },
  }
}

om:connect("objects-changed", function (om)
  local new_seen_devices = {}
  for device in om:iterate() do
    if not seen_devices[device["bound-id"]] then
      seen_devices[device["bound-id"]] = true
      device:connect("params-changed", handleDevice)
      handleDevice(device)
    end
    new_seen_devices[device["bound-id"]] = true
  end
  seen_devices = new_seen_devices
end)

om:activate()

dsp_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "media.class", "equals", "Audio/Sink" },
    Constraint { "node.name", "equals", "audio_effect.t2-161-speakers" },
  }
}

dsp_om:connect("objects-changed", function (om)
  for node in om:iterate() do
    handleDspSink(node)
  end
end)

dsp_om:activate()
