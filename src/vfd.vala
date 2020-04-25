public class VFD : GLib.Object {
    private Modbus.Context modbus;

    public bool is_connected = false;

    public string device = "/dev/ttyUSB0";
    public int baud = 19200;
    public char parity = 'N';
    public int data_bits = 8;
    public int stop_bits = 1;

    public int slave_id = 1;

    public new bool connect () {
        debug("Opening modbus connection");

        modbus = new Modbus.Context.rtu (device, baud, parity, data_bits, stop_bits);
        modbus.set_debug(true);
        modbus.rtu_set_rts(1);

        if (modbus.set_slave (slave_id) == -1 ) {
            error ("Failed to set rs485 slave.");
        }

        if (modbus.connect () == -1) {
            is_connected = false;
        } else {
            is_connected = true;
        }

        return is_connected;
    }

    public new void disconnect () {
        debug("Closing modbus connection");
        is_connected = false;
        modbus.close ();
    }

    public string get_raw_parameter_value (Parameter parameter) {
        int register = 0x100 * parameter.group.integer + parameter.integer;
        uint16 val = 0;
        if (modbus.read_registers (register, 1, &val) == -1) {
            error ("Modbus read error.");
        } else {
            return val.to_string ();
        }
    }

    public string get_parameter_value (Parameter parameter) {
        int register = 0x100 * parameter.group.integer + parameter.integer;
        uint16 val = 0;
        if (modbus.read_registers (register, 1, &val) == -1) {
            error ("Modbus read error.");
        } else {
            if (parameter.has_options) {
                return parameter.option (val.to_string ()).name;
            } else if (parameter.scale == 1) {
                return val.to_string ();
            } else {
                char[] buffer = new char[double.DTOSTR_BUF_SIZE];
                return (val * parameter.scale).format(buffer, parameter.format);
            }
        }
    }

    public VFD () { }
}
