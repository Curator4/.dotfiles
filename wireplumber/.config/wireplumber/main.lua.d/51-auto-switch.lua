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
