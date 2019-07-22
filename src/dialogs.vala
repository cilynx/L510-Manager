public class ProgressDialog : Gtk.Dialog {
    private Gtk.ProgressBar progress_bar;
    private Gtk.Label label = new Gtk.Label ("");

    public int total;

    public string text {
        set { label.set_text (value); }
    }

    public int current {
        set { percentage = ((double) value / (double) total); }
    }

    public double percentage {
        set {
            var pct = value.clamp (0.0, 1.0);
            show_all ();
            while (Gtk.events_pending ())
                Gtk.main_iteration ();
            progress_bar.set_fraction (pct);
            progress_bar.set_text (("%d%%").printf ((int) (pct * 100.0)));
        }
    }

    public ProgressDialog (Gtk.Window? owner, string title) {
        if (owner != null) { set_transient_for (owner); }

        this.set_title(title);

        progress_bar = new Gtk.ProgressBar ();
        progress_bar.width_request = 300;
        progress_bar.show_text = true;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 12;
        grid.margin = 12;
        grid.margin_top = 0;
        grid.add (label);
        grid.add (progress_bar);

        get_content_area ().add(grid);
    }

}
