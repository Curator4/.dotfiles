-- Automatically switch audio to newly connected devices
rule = {
  matches = {
    {
      { "node.name", "matches", "bluez_output.*" },
    },
  },
  apply_properties = {
    ["device.profile-set"] = "auto",
    ["priority.session"] = 2000,
  },
}

table.insert(alsa_monitor.rules, rule)

-- Move existing streams to new default device
default_nodes_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "default" },
  }
}

links_om = ObjectManager {
  Interest {
    type = "link",
  }
}

nodes_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "media.class", "matches", "Stream/*", type = "pw-global" },
  }
}

default_nodes_om:connect("object-added", function (om, metadata)
  metadata:connect("changed", function (m, subject, key, t, value)
    if key == "default.audio.sink" and value ~= nil then
      -- New default sink set, move all playback streams
      for node in nodes_om:iterate() do
        local media_class = node.properties["media.class"]
        if media_class == "Stream/Output/Audio" then
          local target = node.properties["target.object"]
          -- Only move if not already on the new default
          if target ~= value then
            node:set_param("Props", Pod.Object {
              "Spa:Pod:Object:Param:Props", "Props",
              target = value
            })
          end
        end
      end
    elseif key == "default.audio.source" and value ~= nil then
      -- New default source set, move all capture streams
      for node in nodes_om:iterate() do
        local media_class = node.properties["media.class"]
        if media_class == "Stream/Input/Audio" then
          local target = node.properties["target.object"]
          if target ~= value then
            node:set_param("Props", Pod.Object {
              "Spa:Pod:Object:Param:Props", "Props",
              target = value
            })
          end
        end
      end
    end
  end)
end)

default_nodes_om:activate()
links_om:activate()
nodes_om:activate()
