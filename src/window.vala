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

        private VFD_Config vfd_config = new VFD_Config ("/com/wolfteck/L510Manager/json/parameters.json");
        private VFD vfd = new VFD ();

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
                if (path != null) {
                    if (!vfd.is_connected) { vfd.connect (); }
                    if (vfd.is_connected) {
                        ProgressDialog progress_dialog = new ProgressDialog(this, "Saving Profile from VFD state");
                        progress_dialog.total = vfd_config.parameter_count + vfd_config.group_count;
                        int index = 0;
                        string group_number = null;
                        string last_group = "00";
                        Json.Builder profile = new Json.Builder ();
                        profile.begin_object ();
                        profile.set_member_name (last_group);
                        profile.begin_object ();
                        all_parameters_treeview.get_model ().@foreach((model, path, iter) => {
                            string parameter_number = null;
                            model.get(iter, GROUP_COLUMN, &group_number, PARAMETER_COLUMN, &parameter_number, -1);

                            if (group_number != last_group) {
                                profile.set_member_name ("name");
                                profile.add_string_value (vfd_config.get_group(group_number).name);
                                profile.end_object ();
                                profile.set_member_name (group_number);
                                profile.begin_object ();
                                last_group = group_number;
                            }

                            if (parameter_number != null) {
                                Parameter parameter = vfd_config.get_parameter(group_number + "-" + parameter_number);
                                profile.set_member_name (parameter_number);
                                profile.begin_object ();
                                profile.set_member_name ("default");
                                profile.add_string_value (parameter._dflt);
                                if (parameter.has_options) {
                                    profile.set_member_name ("options");
                                    profile.begin_object ();
                                    foreach (Option option in parameter.options) {
                                        profile.set_member_name(option.id);
                                        profile.add_string_value(option.name);
                                    }
                                    profile.end_object ();
                                }
                                profile.set_member_name ("name");
                                profile.add_string_value (parameter.name);
                                if (parameter.unit != null) {
                                    profile.set_member_name ("unit");
                                    profile.add_string_value(parameter.unit);
                                }
                                profile.set_member_name ("value");
                                profile.add_string_value (vfd.get_raw_parameter_value (parameter));
                                profile.end_object ();
                                progress_dialog.text = parameter.group.name;
                            }
                            progress_dialog.current = ++index;
                            if (index == progress_dialog.total) {
                                progress_dialog.close ();
                            }
                            return false;
                        });
                        profile.set_member_name ("name");
                        profile.add_string_value (vfd_config.get_group(group_number).name);
                        profile.end_object ();
                        profile.end_object ();
                        Json.Generator generator = new Json.Generator ();
                        Json.Node root = profile.get_root ();
                        generator.set_root (root);
                        generator.pretty = true;
                        generator.indent = 3;
                        generator.to_file (path);
                    } else {
                        var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, "VFD not connected!");
                        dialog.run ();
                        dialog.destroy ();
                    }
                    print ("Save " + path + "\n");
                }
            });
            this.add_action (save_profile_action);

            var connect_vfd_action = new SimpleAction.stateful ("connect_vfd", null, new Variant.boolean (false));
            connect_vfd_action.activate.connect (() => {
                debug ("Action %s activated\n", connect_vfd_action.get_name ());
                bool widget_is_checked = connect_vfd_action.get_state ().get_boolean ();
                if (widget_is_checked) {
                    vfd.disconnect ();
                } else {
                    if (vfd.connect ()) {
                        ProgressDialog progress_dialog = new ProgressDialog(this, "Loading Parameters from VFD");
                        progress_dialog.total = vfd_config.parameter_count + vfd_config.group_count;

                        int index = 0;
                        all_parameters_treeview.get_model ().@foreach((model, path, iter) => {
                            string group_number = null;
                            string parameter_number = null;
                            model.get(iter, GROUP_COLUMN, &group_number, PARAMETER_COLUMN, &parameter_number, -1);

                            if (parameter_number != null) {
                                Parameter parameter = vfd_config.get_parameter(group_number + "-" + parameter_number);
                                ((Gtk.TreeStore) model).set_value(iter, VFD_COLUMN, vfd.get_parameter_value (parameter));
                                progress_dialog.text = parameter.group.name;
                            }
                            progress_dialog.current = ++index;
                            if (index == progress_dialog.total) {
                                progress_dialog.close ();
                                // primary_menu_button.get_popover ().hide ();
                            }
                            return false;
                        });
                    } else {
                        var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK, "Error connecting to VFD.  Check serial parameters.");
                        dialog.run ();
                        dialog.destroy ();
                   }
                }
                connect_vfd_action.set_state (new Variant.boolean (vfd.is_connected));
            });
            this.add_action (connect_vfd_action);

            var device_action = new SimpleAction.stateful ("device", VariantType.STRING, new Variant.string ("/dev/ttyUSB0"));
            device_action.activate.connect((target) => {
                vfd.device = target.get_string ();
                device_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (device_action);

            var baud_action = new SimpleAction.stateful ("baud", VariantType.STRING, new Variant.string ("19200"));
            baud_action.activate.connect((target) => {
                vfd.baud = int.parse(target.get_string ());
                baud_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (baud_action);

            var data_bits_action = new SimpleAction.stateful ("data_bits", VariantType.STRING, new Variant.string ("8"));
            data_bits_action.activate.connect((target) => {
                vfd.data_bits = int.parse (target.get_string ());
                data_bits_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (data_bits_action);

            var parity_action = new SimpleAction.stateful ("parity", VariantType.STRING, new Variant.string ("N"));
            parity_action.activate.connect((target) => {
                vfd.parity = (char) target.get_string ().get_char ();
                parity_action.set_state (target);
                debug (@"state change to $(target.get_string())\n");
            });
            this.add_action (parity_action);

            var stop_bits_action = new SimpleAction.stateful ("stop_bits", VariantType.STRING, new Variant.string ("1"));
            stop_bits_action.activate.connect((target) => {
                vfd.stop_bits = int.parse (target.get_string ());
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
                    if (vfd.is_connected) {
                        store.set_value(iter, VFD_COLUMN, vfd.get_parameter_value(parameter));
                    }
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
