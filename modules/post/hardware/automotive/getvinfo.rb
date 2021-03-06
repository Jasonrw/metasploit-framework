##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'rex'
require 'msf/core/post/hardware/automotive/uds'

class MetasploitModule < Msf::Post

  include Msf::Post::Hardware::Automotive::UDS

  def initialize(info={})
    super( update_info( info,
        'Name'          => 'Get the Vehicle Information Such as the VIN from the Target Module',
        'Description'   => %q{ Post Module to query DTCs, Some common engine info and Vehicle Info.
                               It returns such things as engine speed, coolant temp, Diagnostic
                               Trouble Codes as well as All info stored by Mode $09 Vehicle Info, VIN, etc},
        'License'       => MSF_LICENSE,
        'Author'        => ['Craig Smith'],
        'Platform'      => ['hardware'],
        'SessionTypes'  => ['hwbridge']
      ))
    register_options([
      OptInt.new('SRCID', [true, "Module ID to query", 0x7e0]),
      OptInt.new('DSTID', [false, "Expected reponse ID, defaults to SRCID + 8", 0x7e8]),
      OptBool.new('CLEAR_DTCS', [false, "Clear any DTCs and reset MIL if errors are present", false]),
      OptString.new('CANBUS', [false, "CAN Bus to perform scan on, defaults to connected bus", nil])
    ], self.class)

  end

  def run
    pids = get_current_data_pids(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
    if pids.size == 0
      print_status("No reported PIDs. You may not be properly connected")
    else
      print_status("Available PIDS for pulling realtime data: #{pids.size} pids")
      print_status("  #{pids.inspect}")
    end
    if pids.include? 1
      data = get_monitor_status(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
      print_status("  MIL (Engine Light) : #{data["MIL"] ? "ON" : "OFF"}") if data.has_key? "MIL"
      print_status("  Number of DTCs: #{data["DTC_COUNT"]}") if data.has_key? "DTC_COUNT"
    end
    if pids.include? 5
      data = get_engine_coolant_temp(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
      print_status("  Engine Temp: #{data["TEMP_C"]} \u00b0C / #{data["TEMP_F"]} \u00b0F") if data.has_key? "TEMP_C"
    end
    if pids.include? 0x0C
      data = get_rpms(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
      print_status("  RPMS: #{data["RPM"]}") if data.has_key? "RPM"
    end
    if pids.include? 0x0D
      data = get_vehicle_speed(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
      print_status("  Speed: #{data["SPEED_K"]} km/h  /  #{data["SPEED_M"]} mph") if data.has_key? "SPEED_K"
    end
    if pids.include? 0x1C
      print_status("Supported OBD Standards: #{get_obd_standards(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])}")
    end
    dtcs = get_dtcs(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
    print_status("DTCs: #{ dtcs.join(",") }") if dtcs.size > 0
    pids = get_vinfo_supported_pids(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
    print_status("Mode $09 Vehicle Info Supported PIDS: #{pids.inspect}") if pids.size > 0
    pids.each do |pid|
      # Handle known pids
      if pid == 2
        vin = get_vin(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
        print_status("VIN: #{vin}")
      elsif pid == 4
        calid = get_calibration_id(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
        print_status("Calibration ID: #{calid}")
      elsif pid == 0x0A
        ecuname = get_ecu_name(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
        print_status("ECU Name: #{ecuname}")
      else
        data = get_vehicle_info(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"], pid)
        data = response_hash_to_data_array(datastore["DSTID"].to_s(16), data)
        print_status("PID #{pid} Response: #{data.inspect}")
      end
    end
    if datastore['CLEAR_DTCS'] == true
      clear_dtcs(datastore["CANBUS"], datastore["SRCID"], datastore["DSTID"])
      print_status("Cleared DTCs and reseting MIL")
    end
  end

end
