/* window.vala
 *
 * Copyright 2019 Randy C. Will
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace L510_manager {
	[GtkTemplate (ui = "/com/wolfteck/L510Manager/window.ui")]
	public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        Gtk.TreeView all_parameters_treeview;

        [GtkChild]
        Gtk.TreeView parameter_sets_treeview;

        [GtkChild]
        Gtk.TreeView parameter_set_treeview;

        [GtkChild]
        Gtk.Label parameter_set_label;
/*
        [GtkChild]
        Menu device_menu;
*/
        static int GROUP_COLUMN = 0;
        static int PARAMETER_COLUMN = 1;
        static int NAME_COLUMN = 2;
        static int DEFAULT_COLUMN = 3;
        static int PROFILE_COLUMN = 4;
        static int VFD_COLUMN = 5;
        static int UNIT_COLUMN = 6;

        private Modbus.Context modbus;

		public Window (Gtk.Application app) {
			Object (application: app);

            setup_all_parameters_treeview (all_parameters_treeview);

            setup_parameter_sets_treeview (parameter_sets_treeview);
            var parameter_set_selection = parameter_sets_treeview.get_selection ();
            parameter_set_selection.changed.connect (this.on_perameter_sets_selection_changed);

            setup_parameter_columns (parameter_set_treeview);

            var new_profile_action = new SimpleAction ("new_profile", null);
            new_profile_action.activate.connect (() => {
        	    print ("New\n");
            });
            this.add_action (new_profile_action);

            var open_profile_action = new SimpleAction ("open_profile", null);
            open_profile_action.activate.connect(() => {
                var path = Dialogs.open_file(this);
                print ("Open " + path + "\n");
            });
            this.add_action (open_profile_action);

            var save_profile_action = new SimpleAction ("save_profile", null);
            save_profile_action.activate.connect(() => {
                var path = Dialogs.save_file(this);
                print ("Save " + path + "\n");
            });
            this.add_action (save_profile_action);

            var connect_serial_action = new SimpleAction.stateful ("connect_serial", null, new Variant.boolean (false));
		    connect_serial_action.activate.connect (() => {
                debug ("Action %s activated\n", connect_serial_action.get_name ());
                Variant state = connect_serial_action.get_state ();
    			bool is_open = state.get_boolean ();
                if (is_open) {
                    debug("Closing modbus connection");
           			modbus.close ();
                } else {
                    debug("Opening modbus connection");
        			modbus = new Modbus.Context.rtu ("/dev/ttyUSB0", 19200, 'N', 8, 1);
                    modbus.set_debug(true);
                    modbus.rtu_set_rts(1);

        			if (modbus.set_slave (1) == -1 ) {
        			    error ("Failed to set rs485 slave.");
        			}

        			if (modbus.connect () == -1) {
        			    error ("Connection failed.");
        			}

                    all_parameters_treeview.get_model ().@foreach((model, path, iter) => {
                        string group_number = null;
                        string parameter_number = null;
                        string default_value = null;

                        model.get(iter, GROUP_COLUMN, &group_number, PARAMETER_COLUMN, &parameter_number, DEFAULT_COLUMN, &default_value, -1);

                        if (parameter_number != null) {
                            int group_int = int.parse (group_number);
                            int parameter_int = int.parse (parameter_number);
                            int register = 0x100 * group_int + parameter_int;
                            uint16 val = 0;
                            if (modbus.read_registers (register, 1, &val) == -1) {
                                error ("Modbus read error.");
                            } else {
                                if (default_value != null && default_value.contains(".")) {
                                    double scale = (default_value.length - default_value.index_of_char ('.') == 2) ? 0.1 : 0.01;
                                    string format = (scale == 0.1) ? "%.1f" : "%.2f";
                                    char[] buffer = new char[double.DTOSTR_BUF_SIZE];
                                    ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, (val * scale).format(buffer, format));
                                } else {
                                    ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, val);
                                }
                            }
                        }
                        return false;
                    });
                }
    			connect_serial_action.set_state (new Variant.boolean (!is_open));
            });
            this.add_action (connect_serial_action);

            var device_action = new SimpleAction.stateful ("device", VariantType.STRING, new Variant.string ("/dev/ttyUSB0"));
            device_action.activate.connect((target) => {
                device_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (device_action);

            var baud_action = new SimpleAction.stateful ("baud", VariantType.STRING, new Variant.string ("19200"));
            baud_action.activate.connect((target) => {
                baud_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (baud_action);

            var data_bits_action = new SimpleAction.stateful ("data_bits", VariantType.STRING, new Variant.string ("8"));
            data_bits_action.activate.connect((target) => {
                data_bits_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (data_bits_action);

            var parity_action = new SimpleAction.stateful ("parity", VariantType.STRING, new Variant.string ("N"));
            parity_action.activate.connect((target) => {
                parity_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (parity_action);

            var stop_bits_action = new SimpleAction.stateful ("stop_bits", VariantType.STRING, new Variant.string ("1"));
            stop_bits_action.activate.connect((target) => {
                stop_bits_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (stop_bits_action);
		}

        private void on_perameter_sets_selection_changed (Gtk.TreeSelection selection) {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            string parameter_set_name;

            if (selection.get_selected (out model, out iter)) {
                model.get (iter, 0, out parameter_set_name);
                parameter_set_label.set_text (parameter_set_name);
                var store = new Gtk.TreeStore (7,
                    typeof (string),
                    typeof (string),
                    typeof (string),
                    typeof (string),
                    typeof (string),
                    typeof (string),
                    typeof (string)
                    );
    		    parameter_set_treeview.set_model (store);

    		    try {
        		    // Fetch parameter set from JSON
        		    var parameter_sets_stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameter_sets.json", ResourceLookupFlags.NONE);
        		    Json.Parser parser = new Json.Parser ();
        		    parser.load_from_stream (parameter_sets_stream);
        		    var parameter_set = parser.get_root ().get_object ().get_member (parameter_set_name);

        		    // Grab array from parameter set
        		    var parameter_array = parameter_set.get_array ();

    		        // Fetch parameters from JSON
                    Json.Parser all_parameters_parser = new Json.Parser ();
                    var all_parameters_stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameters.json", ResourceLookupFlags.NONE);
        		    all_parameters_parser.load_from_stream (all_parameters_stream);
        		    var parameters_root = all_parameters_parser.get_root ().get_object ();

                    // Add parameters to TreeStore
                    parameter_array.foreach_element ((array, index, node) => {
                        string[] coordinates = node.get_string ().split ("-");
        		        var group_number = coordinates[0];
        		        var parameter_number = coordinates[1];

                        var parameter = parameters_root.get_member (group_number).get_object ().get_member (parameter_number).get_object ();
        		        store.insert_with_values (out iter, null, -1,
        		            GROUP_COLUMN, group_number,
        		            PARAMETER_COLUMN, parameter_number,
        		            NAME_COLUMN, parameter.get_string_member ("name"),
        		            -1);
           		        if (parameter.has_member ("unit")) {
           		            store.set_value(iter, UNIT_COLUMN, parameter.get_string_member ("unit"));
        		        }
        		        if (parameter.has_member ("default")) {
           		            store.set_value(iter, DEFAULT_COLUMN, parameter.get_string_member ("default"));
        		        }
                    });
                } catch (GLib.Error e) {
                    error ("can't load resource: %s", e.message);
                }
            }
        }

        private void setup_parameter_sets_treeview (Gtk.TreeView view) {
            var store = new Gtk.TreeStore (2, typeof (string), typeof (string));
		    view.set_model (store);

            view.insert_column_with_attributes(-1, "Parameter Set", new Gtk.CellRendererText (), "text", 0, null);

		    Gtk.TreeIter iter;
		    try {
                var stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameter_sets.json", ResourceLookupFlags.NONE);
                Json.Parser parser = new Json.Parser ();
                parser.load_from_stream (stream);
                var parameter_sets = parser.get_root ().get_object ();
                foreach (string parameter_set_name in parameter_sets.get_members ()) {
                    var parameter_set = parameter_sets.get_member (parameter_set_name);
                    store.insert_with_values (out iter, null, -1, 0, parameter_set_name, 1, parameter_set.get_array, -1);
                }
		    } catch (GLib.Error e) {
                error ("can't load parameters from resource: %s", e.message);
            }
        }

        private void setup_parameter_columns (Gtk.TreeView view) {
            var profile_cell = new Gtk.CellRendererText ();
		    profile_cell.editable = true;
		    profile_cell.edited.connect ((path, new_text) => {

		    });

            view.insert_column_with_attributes(-1, "Group", new Gtk.CellRendererText (), "text", GROUP_COLUMN, null);
		    view.insert_column_with_attributes(-1, "Number", new Gtk.CellRendererText (), "text", PARAMETER_COLUMN, null);
		    view.insert_column_with_attributes(-1, "Parameter", new Gtk.CellRendererText (), "text", NAME_COLUMN, null);
		    view.insert_column_with_attributes(-1, "Default", new Gtk.CellRendererText (), "text", DEFAULT_COLUMN, null);
		    view.insert_column_with_attributes(-1, "Profile", profile_cell, "text", PROFILE_COLUMN, null);
		    view.insert_column_with_attributes(-1, "VFD", new Gtk.CellRendererText (), "text", VFD_COLUMN, null);
		    view.insert_column_with_attributes(-1, "Unit", new Gtk.CellRendererText (), "text", UNIT_COLUMN, null);
        }

		private void setup_all_parameters_treeview (Gtk.TreeView view) {
		    var store = new Gtk.TreeStore (7,
		        typeof (string),
		        typeof (string),
		        typeof (string),
		        typeof (string),
		        typeof (string),
		        typeof (string),
		        typeof (string)
		    );
		    view.set_model (store);

            this.setup_parameter_columns (view);

            Gtk.TreeIter group_iter;
            Gtk.TreeIter parameter_iter;
            try {
                var stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameters.json", ResourceLookupFlags.NONE);
                Json.Parser parser = new Json.Parser ();
                parser.load_from_stream (stream);
                var parameters = parser.get_root ().get_object ();
                foreach (string group_number in parameters.get_members ()) {
                    var group = parameters.get_member (group_number).get_object ();
                    store.insert_with_values (out group_iter, null, -1,
                        GROUP_COLUMN, group_number,
                        NAME_COLUMN, group.get_string_member ("name"),
                        -1);
                    foreach (string parameter_number in group.get_members ()) {
                        if (parameter_number != "name") {
                            var parameter = group.get_member (parameter_number).get_object ();
                            store.insert_with_values (out parameter_iter, group_iter, -1,
                                GROUP_COLUMN, group_number,
                                PARAMETER_COLUMN, parameter_number,
                                NAME_COLUMN, parameter.get_string_member ("name"),
                                -1);
               		        if (parameter.has_member ("unit")) {
               		            store.set_value(parameter_iter, UNIT_COLUMN, parameter.get_string_member ("unit"));
            		        }
            		        if (parameter.has_member ("default")) {
               		            store.set_value(parameter_iter, DEFAULT_COLUMN, parameter.get_string_member ("default"));
            		        }
                        }
                    }
                }
            } catch (GLib.Error e) {
                error ("can't load parameters from resource: %s", e.message);
            }
		}
	}
}
