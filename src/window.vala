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
        Gtk.MenuButton primary_menu_button;
*/
        static int GROUP_COLUMN = 0;
        static int PARAMETER_COLUMN = 1;
        static int NAME_COLUMN = 2;
        static int DEFAULT_COLUMN = 3;
        static int PROFILE_COLUMN = 4;
        static int VFD_COLUMN = 5;
        static int UNIT_COLUMN = 6;

        private Modbus.Context modbus;

        private VFD_Config vfd_config = new VFD_Config ("/com/wolfteck/L510Manager/json/parameters.json");

        public Window (Gtk.Application app) {
            Object (application: app);

            setup_all_parameters_treeview (all_parameters_treeview);

            setup_parameter_sets_treeview (parameter_sets_treeview);
            var parameter_set_selection = parameter_sets_treeview.get_selection ();
            parameter_set_selection.changed.connect (this.on_parameter_sets_selection_changed);

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

                    ProgressDialog progress_dialog = new ProgressDialog(this, "Loading Parameters from VFD");
                    progress_dialog.total = vfd_config.parameter_count + vfd_config.group_count;

                    int index = 0;
                    all_parameters_treeview.get_model ().@foreach((model, path, iter) => {
                        string group_number = null;
                        string parameter_number = null;
                        model.get(iter, GROUP_COLUMN, &group_number, PARAMETER_COLUMN, &parameter_number, -1);

                        if (parameter_number != null) {
                            Parameter parameter = vfd_config.get_parameter(group_number + "-" + parameter_number);
                            int register = 0x100 * parameter.group.integer + parameter.integer;
                            uint16 val = 0;
                            if (modbus.read_registers (register, 1, &val) == -1) {
                                error ("Modbus read error.");
                            } else {
                                if (parameter.has_options) {
                                    ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, parameter.option (val.to_string ()).name);
                                } else if (parameter.scale == 1) {
                                    ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, val);
                                } else {
                                    char[] buffer = new char[double.DTOSTR_BUF_SIZE];
                                    ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, (val * parameter.scale).format(buffer, parameter.format));
                                }
                            }
                            progress_dialog.text = parameter.group.name;
                        }
                        progress_dialog.current = ++index;
                        if (index == progress_dialog.total) {
                            progress_dialog.close ();
                            // primary_menu_button.get_popover ().hide ();
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

        private void on_parameter_sets_selection_changed (Gtk.TreeSelection selection) {
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

                Group parameter_set = vfd_config.get_parameter_set (parameter_set_name);
                foreach (Parameter parameter in parameter_set.get_parameters ()) {
                    store.insert_with_values (out iter, null, -1,
                        GROUP_COLUMN, parameter.group.number,
                        PARAMETER_COLUMN, parameter.number,
                        NAME_COLUMN, parameter.name,
                        UNIT_COLUMN, parameter.unit,
                        DEFAULT_COLUMN, parameter.dflt,
                        -1);
                }
            }
        }

        private void setup_parameter_sets_treeview (Gtk.TreeView view) {
            vfd_config.load_parameter_sets ("/com/wolfteck/L510Manager/json/parameter_sets.json");

            var store = new Gtk.TreeStore (2, typeof (string), typeof (string));
            view.set_model (store);
            view.insert_column_with_attributes(-1, "Parameter Set", new Gtk.CellRendererText (), "text", 0, null);

            Gtk.TreeIter iter;
            foreach (Group parameter_set in vfd_config.get_parameter_sets ()) {
                store.insert_with_values (out iter, null, -1, 0, parameter_set.name, -1);
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
            foreach (Group group in vfd_config.get_groups ()) {
                store.insert_with_values (out group_iter, null, -1,
                    GROUP_COLUMN, group.number,
                    NAME_COLUMN, group.name,
                    -1);
                foreach (Parameter parameter in group.get_parameters ()) {
                    store.insert_with_values (out parameter_iter, group_iter, -1,
                        GROUP_COLUMN, group.number,
                        PARAMETER_COLUMN, parameter.number,
                        NAME_COLUMN, parameter.name,
                        DEFAULT_COLUMN, parameter.dflt,
                        UNIT_COLUMN, parameter.unit,
                        -1);
                }
            }
        }
    }
}
