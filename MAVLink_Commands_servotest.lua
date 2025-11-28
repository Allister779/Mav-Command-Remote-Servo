-- Example of receiving MAVLink commands

local mavlink_msgs = require("MAVLink/mavlink_msgs")

local COMMAND_ACK_ID = mavlink_msgs.get_msgid("COMMAND_ACK")
local COMMAND_LONG_ID = mavlink_msgs.get_msgid("COMMAND_LONG")

local msg_map = {}
msg_map[COMMAND_ACK_ID] = "COMMAND_ACK"
msg_map[COMMAND_LONG_ID] = "COMMAND_LONG"

-- initialize MAVLink rx with number of messages, and buffer depth
mavlink:init(2, 10)

-- register message id to receive
mavlink:register_rx_msgid(COMMAND_LONG_ID)

local MAV_CMD_DO_SET_MODE = 176
local MAV_CMD_WAYPOINT_USER_1 = 31000
local MAV_CMD_DO_SET_SERVO = 183


-- Block AP parsing user1 so we can deal with it in the script
-- Prevents "unsupported" ack
mavlink:block_command(MAV_CMD_WAYPOINT_USER_1)


-- Send a mavlink command when the flight mode is changed.

function handle_command_long(cmd)

    local message = mavlink_msgs.encode("COMMAND_LONG", {
        target_system = 1,        -- Target system
        target_component = 1,     -- Target component
        command = 183,        -- MAVLink command ID
        confirmation = 0,         -- 0 for no confirmation
        param1 = 8,   -- Servo 8
        param2 = 1510, -- move to 1510
        param3 = 0,
        param4 = 0,
        param5 = 0,
        param6 = 0,
        param7 = 0
    })

    if (cmd.command == MAV_CMD_DO_SET_MODE) then
        gcs:send_text(0, "Got mode change")
        mavlink:send_chan(0,76, message)
    
    elseif (cmd.command == MAV_CMD_WAYPOINT_USER_1) then
        -- return ack from command param value
        return math.min(math.max(math.floor(cmd.param1), 0), 5)
    end
    
    if (cmd.command == MAV_CMD_DO_SET_SERVO) then
        gcs:send_text(0, "servo test")
    end
    
    return nil
end

function update()
    local msg, chan = mavlink:receive_chan()
    if (msg ~= nil) then
        local parsed_msg = mavlink_msgs.decode(msg, msg_map)
        if (parsed_msg ~= nil) then

            local result
            if parsed_msg.msgid == COMMAND_LONG_ID then
                result = handle_command_long(parsed_msg)
            end

            if (result ~= nil) then
                -- Send ack if the command is one were intrested in
                local ack = {}
                ack.command = parsed_msg.command
                ack.result = result
                ack.progress = 0
                ack.result_param2 = 0
                ack.target_system = parsed_msg.sysid
                ack.target_component = parsed_msg.compid

                mavlink:send_chan(chan, mavlink_msgs.encode("COMMAND_ACK", ack))
            end
        end
    end

    return update, 1000
end

return update()
