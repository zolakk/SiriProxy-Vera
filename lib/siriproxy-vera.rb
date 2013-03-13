require 'cora'
require 'siri_objects'
require 'pp'
require 'httparty'
require 'json'

# This code originally written by rlmalisz on the MicasaVerde forum
# 3-12-2013 - Minor modification made to change fan control over to FanLinc
#######
# Here goes nothing
######

class SiriProxy::Plugin::Vera < SiriProxy::Plugin
  def initialize(config = {})
    @action_url = config["action_url"]
    @switch_light = config["switch_light"]
    @set_level = config["set_level"]
    @get_status = config["get_status"]
    @run_scene = config["run_scene"]
    @set_fan = config["insteon_fan"]
    # so we'll try to set up a hash of our configuration
    @rooms = {
      "living"=>{
        "name"=>"living room",
        "prep"=>" in ",
        "lights"=> { "table lamps"=>"15","fan light"=>"41","front door"=>"16","overhead light"=>"41" },
        "dimmers"=>{ "table lamps"=>"15","fan light"=>"41","front door"=>"16","overhead light"=>"41" },
        "outlets"=>{},
        "fans"=>{ "overhead"=>"42" },
        "locks"=>{ "door lock"=>"50" },
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "dining"=>{
        "name"=>"dining room",
        "prep"=>" in ",
        "lights"=> { "chandelier"=>"54","tall lamp"=>22 },
        "dimmers"=>{ "chandelier"=>"54","tall lamp"=>22 },
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "kitchen"=>{
        "name"=>"kitchen",
        "prep"=>" in ",
        "lights"=> { "sink"=>"18", "island"=>"13", "slider"=>"14" },
        "dimmers"=>{ "sink"=>"18", "island"=>"50", "slider"=>"14" },
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "back"=>{
        "name"=>"out back",
        "prep"=>" ",
        "lights"=> { "grill"=>"8", "kennel"=>"22", "shed"=>"52" },
        "dimmers"=>{ "kennel"=>"22" },
        "outlets"=>{ "grill"=>"38" },
        "fans"=>{},
        "locks"=>{ "garden shed"=>"14" },
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "front"=>{
        "name"=>"out front",
        "prep"=>" ",
        "lights"=> { "patio"=>"17" },
        "dimmers"=>{},
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{"door lock"=>"50" },
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "master"=>{
        "name"=>"master bedroom",
        "prep"=>" in ",
        "lights"=> { "bathroom"=>"77", "side tables"=>"20" },
        "dimmers"=>{ "bathroom"=>"77", "side tables"=>"20" },
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "hallway"=>{
        "name"=>"hallway",
        "prep"=>" in ",
        "lights"=>{ "lights"=>"19" },
        "dimmers"=>{ "lights"=>"19" },
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{ "Nest"=>"74"},
        "scenes"=>{}
      },
      "office"=>{
        "name"=>"office",
        "prep"=>" in ",
        "lights"=>{ "overhead"=>"51" },
        "dimmers"=>{ "overhead"=>"51" },
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "garage"=>{
        "name"=>"garage",
        "prep"=>" in ",
        "lights"=>{"light"=>"59"},
        "dimmers"=>{},
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{},
        "sensors"=>{},
        "thermostats"=>{},
        "scenes"=>{}
      },
      "any"=>{
        "name"=>"any room",
        "prep"=>" in ",
        "lights"=>{},
        "dimmers"=>{},
        "outlets"=>{},
        "fans"=>{},
        "locks"=>{ "front deadbolt"=>"50" },
        "sensors"=>{},
        "thermostats"=>{ "hallway"=>"74" },
        "scenes"=>{ "lights out"=>"1", "movie time on"=>"37", "movie time off"=>"58" }
      }
    }
    @current_room = "any"
    @fan_map = {
      "off"=>"0",
      "low"=>"1",
      "medium"=>"2",
      "high"=>"3"
    }
    @fan_rmap = {
      "0"=>"off",
      "1"=>"low",
      "2"=>"medium",
      "3"=>"high"
    }
    # we'll build up a hash of the devices we have, keyed on device id
    @dev_map = Hash.new
    seq_num = 0
    rkeys = @rooms.keys
    for rkey in 0...rkeys.length
      # skip "any"
      if rkeys[rkey] != "any"
        room_name = @rooms[rkeys[rkey]]["name"]
        prep = @rooms[rkeys[rkey]]["prep"]
        # types of devices
        tkeys = @rooms[rkeys[rkey]]["locks"].keys
        for tkey in 0...tkeys.length
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["locks"][tkeys[tkey]]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{tkeys[tkey]} lock#{prep}#{room_name} "
          @dev_map[dev_num]["important"] = "locked"
          @dev_map[dev_num]["trigger"] = "0"
          @dev_map[dev_num]["report"] = "unlocked"
        end
        tkeys = @rooms[rkeys[rkey]]["sensors"].keys
        for tkey in 0...tkeys.length
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["sensors"][tkeys[tkey]]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{tkeys[tkey]} door#{prep}#{room_name} "
          @dev_map[dev_num]["important"] = "tripped"
          @dev_map[dev_num]["trigger"] = "1"
          @dev_map[dev_num]["report"] = "open"
        end
        tkeys = @rooms[rkeys[rkey]]["thermostats"].keys
        for tkey in 0...tkeys.length
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["thermostats"][tkeys[tkey]]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{tkeys[tkey]} thermostat#{prep}#{room_name} "
          @dev_map[dev_num]["trigger"] = ""
        end
        tkeys = @rooms[rkeys[rkey]]["fans"].keys
        for tkey in 0...tkeys.length
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["fans"][tkeys[tkey]]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{tkeys[tkey]} fan#{prep}#{room_name} "
          @dev_map[dev_num]["important"] = "fanstate"
          @dev_map[dev_num]["trigger"] = "fan"
          @dev_map[dev_num]["report"] = "on"
        end
        tkeys = @rooms[rkeys[rkey]]["lights"].keys
        for tkey in 0...tkeys.length
          dev_name = tkeys[tkey]
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["lights"][dev_name]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{dev_name} light#{prep}#{room_name} "
          @dev_map[dev_num]["important"] = "status"
          @dev_map[dev_num]["trigger"] = "1"
          @dev_map[dev_num]["report"] = "on"
        end
        tkeys = @rooms[rkeys[rkey]]["outlets"].keys
        for tkey in 0...tkeys.length
          # what's the device number?
          dev_num = @rooms[rkeys[rkey]]["outlets"][tkeys[tkey]]
          @dev_map[dev_num] = Hash.new
          @dev_map[dev_num]["seq"] = seq_num
          seq_num = seq_num + 1
          @dev_map[dev_num]["desc"] = "#{tkeys[tkey]} outlet#{prep}#{room_name} "
          @dev_map[dev_num]["important"] = "status"
          @dev_map[dev_num]["trigger"] = "1"
          @dev_map[dev_num]["report"] = "on"
        end
      end
    end
    #if you have custom configuration options, process them here!
  end

  # house summary
  listen_for (/(house summary|overall status|what's up)/i) {house_summary}

  # silliness--open/close south garage_door
  listen_for (/Open the pod bay door.*/i) \
    { run_scene("toggle south","garage","Pod bay door opened Dave")}

  # movie time
  listen_for (/movie time on.*/i) \
    { run_scene("movie time on","any","Dimmed lights for movies") }

	listen_for (/movie time off.*/i) \
    { run_scene("movie time off","any","Turned lights back on") }

  # lights out
  listen_for (/lights out.*/i) \
    { run_scene("lights out","any","Good night") }

  # panic
  listen_for (/(panic|intruder).*/i) \
    { run_scene("outside on","any","Outside lights on for ten minutes") }

  # context setter
  listen_for /(?:current room|inside|out in|in) (.*)/i do |the_rest|
    keys = @rooms.keys
    lcur_room = nil
    for key in 0...keys.length
      m1 = /#{keys[key]}/i.match("#{the_rest}")
      if (m1 != nil)
         lcur_room = keys[key]
      end
    end
    if (lcur_room != nil)
      @current_room = lcur_room
      say "What would you like to control in #{@rooms[@current_room]["name"]}?"
    else
      say "Room change request to #{the_rest} not understood"
    end
    request_completed 
  end

  # scenes
  listen_for(/execute (.*)/i) \
    {|scene_desc| run_scene(scene_desc,@current_room,"")}

  # binary lights
  listen_for(/(?:turn|switch) (on|off) ,*light/i) \
    {|state| set_binary(state,"lights")}
  listen_for(/(?:turn|switch) (on|off) ,*lights/i) \
    {|state| set_binary(state,"lights")}
  listen_for(/(?:turn|switch) .*light (on|off)/i) \
    {|state| set_binary(state,"lights")}
  listen_for(/(?:turn|switch) .*lights (on|off)/i) \
    {|state| set_binary(state,"lights")}
  # end binary lights

  # dimmers
  listen_for(/(?:set .*light|set|dim) to (100|[1-9][0-9])%/i) \
    {|level| set_dim(level,"dimmers")}
  # end dimmers

  # outlets
  listen_for(/(?:turn|switch) (on|off) outlet/i) \
    {|state| set_binary(state,"outlets")}
  listen_for(/(?:turn|switch) outlet (on|off)/i) \
    {|state| set_binary(state,"outlets")}
  # end outlets

  # fans
  # as on/off devices
  listen_for(/(?:turn|switch) (off) fan/i) \
   {|level| set_fan(level,"fans")}
  listen_for(/(?:turn|switch) fan (off)/i) \
    {|level| set_fan(level,"fans")}
  listen_for(/fan (off)/i) \
    {|level| set_fan(level,"fans")}
  # as variable-speed device
  listen_for(/(?:set fan|set fan to|fan) (off|low|medium|high)/i) \
    {|level| set_fan(level,"fans")}

  # end fans

  def run_scene(scene_desc,room,respond)
    scene_num = 0
    room_name = @rooms[room]["name"]
    keys = @rooms[room]["scenes"].keys
    if keys.length == 0
      say "#{room_name} has no scenes to run"
    else
      scene_name = nil
      for key in 0...keys.length
        m1 = /#{keys[key]}/i.match(scene_desc)
        if (m1 != nil)
          scene_name = keys[key]
        end
      end
      if (scene_name != nil)
        scene_num = @rooms[room]["scenes"][scene_name]
        puts "set scene_num to #{scene_num}"
      else
        say "#{scene_desc} is not a scene in #{room_name}"
      end
    end
    if scene_num != 0
      # make it so
      HTTParty.get("#{@run_scene}#{scene_num}") rescue nil
      puts "Executed #{scene_num}"
      if (respond != "")
        say "#{respond}"
      else
        say "Vera executed #{scene_name} in #{room_name}"
      end
    end
    request_completed
  end
  
  def set_binary(new_state,device_type)
    # do we have more than one relevant device in the current room?  Or any?
    val =  (new_state == "on" ? 1 : 0)
    device_num = 0
    room_name = @rooms[@current_room]["name"]
    keys = @rooms[@current_room][device_type].keys
    if keys.length == 0
      say "#{room_name} has no #{device_type} to turn #{new_state}"
    else
      if keys.length == 1
        # exactly one device, this is easy
        device_name = keys[0]
        device_num = @rooms[@current_room][device_type][keys[0]]
      else
        # we have more than one binary light in the current room, we have
        # to build up a query
        key_query = "Multiple #{device_type}, choose "
        for key in 0...keys.length
          key_query += keys[key]
          if (key < keys.length - 1)
            key_query += " or "
          end
        end
        key_query += " please?"
        response = ask "#{key_query}"
        device_name = nil
        for key in 0...keys.length
          m1 = /#{keys[key]}/i.match("#{response}")
          if (m1 != nil)
            device_name = keys[key]
          end
        end
        if (device_name != nil)
          device_num = @rooms[@current_room]["lights"][device_name]
          puts "set device_num to #{device_num}"
        else
          say "#{response} is not among #{device_type} in #{room_name}"
        end
      end
    end
    if device_num != 0
      # let's light a light, or whatever
      device = "&DeviceNum=#{device_num}"
      dev = device_type.chop
      puts "#{@action_url}#{device}#{@switch_light}=#{val}"
      HTTParty.get("#{@action_url}#{device}#{@switch_light}=#{val}") rescue nil
      say "Vera turned #{new_state} #{room_name} #{device_name} #{dev}"
    end
    request_completed 
  end

  def set_dim(new_level,device_type)
    # do we have more than one dimmable light in the current room?  Or any
    dev = device_type.chop
    device_num = 0
      
    room_name = @rooms[@current_room]["name"]
    keys = @rooms[@current_room][device_type].keys
    if keys.length == 0
      say "#{room_name} has no #{device_type} to set level for"
    else
      if keys.length == 1
        # exactly one light, this is easy
        device_name = keys[0]
        device_num = @rooms[@current_room][device_type][keys[0]]
      else
        # we have more than one relevant device in the current room, we have
        # to build up a query
        key_query = "Multiple #{device_type}, choose "
        for key in 0...keys.length
          key_query += keys[key]
          if (key < keys.length - 1)
            key_query += " or "
          end
        end
        key_query += ", please?"
        response = ask "#{key_query}"
        device_name = nil
        for key in 0...keys.length
          m1 = /#{keys[key]}/i.match("#{response}")
          if (m1 != nil)
            device_name = keys[key]
          end
        end
        if (device_name != nil)
          device_num = @rooms[@current_room][device_type][device_name]
        else
          say "#{response} is not a #{dev} in #{room_name}"
        end
      end
    end
    if device_num != 0
      # let's light a light, or whatever
      device = "&DeviceNum=#{device_num}"
      if dev == "fan"
        vlevel = @fan_map[new_level]
        HTTParty.get("#{@action_url}#{device}#{@set_level}=#{vlevel}") rescue nil
        say "Vera set #{room_name} #{device_name} #{dev} to #{new_level}"
      else
        HTTParty.get("#{@action_url}#{device}#{@set_level}=#{new_level}") rescue nil
        say "Vera set #{room_name} #{device_name} to #{new_level} percent"
      end
    end
    request_completed 
  end

   def set_fan(new_level,device_type)
    # do we have more than one dimmable light in the current room?  Or any
    dev = device_type.chop
    device_num = 0
      
    room_name = @rooms[@current_room]["name"]
    keys = @rooms[@current_room][device_type].keys
    if keys.length == 0
      say "#{room_name} has no #{device_type} to set level for"
    else
      if keys.length == 1
        # exactly one light, this is easy
        device_name = keys[0]
        device_num = @rooms[@current_room][device_type][keys[0]]
      else
        # we have more than one relevant device in the current room, we have
        # to build up a query
        key_query = "Multiple #{device_type}, choose "
        for key in 0...keys.length
          key_query += keys[key]
          if (key < keys.length - 1)
            key_query += " or "
          end
        end
        key_query += ", please?"
        response = ask "#{key_query}"
        device_name = nil
        for key in 0...keys.length
          m1 = /#{keys[key]}/i.match("#{response}")
          if (m1 != nil)
            device_name = keys[key]
          end
        end
        if (device_name != nil)
          device_num = @rooms[@current_room][device_type][device_name]
        else
          say "#{response} is not a #{dev} in #{room_name}"
        end
      end
    end
    if device_num != 0
      # let's light a light, or whatever
      device = "&DeviceNum=#{device_num}"
      vlevel = @fan_map[new_level]
      HTTParty.get("#{@action_url}#{device}#{@set_fan}=#{vlevel}") rescue nil
      say "Vera set #{room_name} #{device_name} #{dev} to #{new_level}"
    end
    request_completed 
  end

  def house_summary()
    page = HTTParty.get("#{@get_status}").body rescue nil
    status = JSON.parse(page) rescue nil
    if status != nil
      devices = status["devices"]
      report_hash = Hash.new
      # let's loop through them
      for index in 0...devices.count
        device = devices[index]
        dev_num = device["id"]
        dev_key = "#{dev_num}"
        dev_name = device["name"]
        # is this one in our map?
        if @dev_map.has_key?(dev_key)
          # first check for triggerless devices--we always report these
          if @dev_map[dev_key]["trigger"] == ""
            dev_seq = @dev_map[dev_key]["seq"]
            # so these will just have a list of fields to report--for now,
            # these are just thermostats.  We can generalize this later
            desc = @dev_map[dev_key]["desc"]
            mode = device["mode"]
            temp = device["temperature"]
            coolsp = device["coolsp"]
            heatsp = device["heatsp"]
            # state = device["hvacstate"]
            if mode == "HeatOn"
              # say "#{desc} set to heat to #{heatsp}, reading #{temp}"
              report_hash[dev_seq] = "#{desc} set to heat to #{heatsp}, reading #{temp}"
            else
              if mode == "CoolOn"
                # say "#{desc} set to cool to #{coolsp}, reading #{temp}"
                report_hash[dev_seq] = "#{desc} set to cool to #{coolsp}, reading #{temp}"
              else
                if mode == "AutoChangeOver"
                  setpoints = "setpoints #{heatsp} and #{coolsp}"
                  # say "#{desc} on auto with #{setpoints}, reading #{temp}"
                  report_hash[dev_seq] = "#{desc} on auto with #{setpoints}, reading #{temp}"
                else
                  # say "#{desc} set to off"
                  report_hash[dev_seq] = "#{desc} set to off"
                end
              end
            end
          else
            if @dev_map[dev_key]["trigger"] == "fan" && device["fanstate"] != "Off"
              desc = @dev_map[dev_key]["desc"]
              report = device["fanstate"]
              dev_seq = @dev_map[dev_key]["seq"]
              report_hash[dev_seq] = "#{desc} is #{report}"
            else
              important = @dev_map[dev_key]["important"]
              dev_trigger = device[important]
              if dev_trigger == @dev_map[dev_key]["trigger"]
                dev_seq = @dev_map[dev_key]["seq"]
                desc = @dev_map[dev_key]["desc"]
                report = @dev_map[dev_key]["report"]
                # say "#{desc} is #{report}"
                report_hash[dev_seq] = "#{desc} is #{report}"
              end
            end
          end
        end
      end
      # we've built up our hash--sort it
      puts "#{report_hash}"
      sorted_hash = report_hash.sort {|a,b| a[0]<=>b[0]}
      for index in 0...sorted_hash.count
        say "#{sorted_hash[index][1]}"
      end
    else
      say "Status request to Vera failed"
    end
    request_completed
  end
end

