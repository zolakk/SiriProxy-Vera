SiriProxy-Vera
==============

A SiriProxy plugin for micasa vera. 
Original code by rlmalisz on the MicasaVerde forums
from: http://forum.micasaverde.com/index.php?topic=9070.msg59577#msg59577

--
Installation
--
Add the following code to your config.yml, substituting <YOUR_VERA_IP_ADDRESS> for the actual address.

    - name: 'Vera'
      git: 'git://github.com/zolakk/SiriProxy-Vera.git'
      action_url: 'http://<YOUR_VERA_IP_ADDRESS>:3480/data_request?id=lu_action&output_format=json'
      switch_light: '&serviceId=urn:upnp-org:serviceId:SwitchPower1&action=SetTarget&newTargetValue'
      set_level: '&serviceId=urn:upnp-org:serviceId:Dimming1&action=SetLoadLevelTarget&newLoadlevelTarget'
      get_status: 'http://<YOUR_VERA_IP_ADDRESS>:3480/data_request?id=lu_sdata&output_format=json'
      run_scene:  'http://<YOUR_VERA_IP_ADDRESS>:3480/data_request?id=lu_action&serviceId=urn:micasaverde-com:serviceId:HomeAutomationGateway1&action=RunScene&SceneNum='
      insteon_fan: '&serviceId=urn:geektaco-info:serviceId:FanLinc1&action=SetFanSpeed&newTargetValue'

may also require the Thermostat plugin enabled to download additional components. Any host will do.
