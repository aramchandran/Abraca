/**
 * Abraca, an XMMS2 client.
 * Copyright (C) 2008  Abraca Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

namespace Abraca {
	public class ToolBar : Gtk.HBox {
		private Gtk.Button play_pause;

		private int _status;
		private int _duration;
		private bool _seek;

		private Gtk.Image _coverart;
		private Gtk.Label _track_label;
		private Gtk.Label _time_label;
		private Gtk.HScale _time_slider;

		construct {
			Client c = Client.instance();
			Gtk.Button btn;

			homogeneous = false;
			spacing = 0;

			_seek = false;

			btn = create_playback_button(Gtk.STOCK_MEDIA_PLAY);
			btn.clicked += on_media_play;

			play_pause = btn;

			btn = create_playback_button(Gtk.STOCK_MEDIA_STOP);
			btn.clicked += on_media_stop;

			btn = create_playback_button(Gtk.STOCK_MEDIA_PREVIOUS);
			btn.clicked += on_media_prev;

			btn = create_playback_button(Gtk.STOCK_MEDIA_NEXT);
			btn.clicked += on_media_next;

			create_seekbar();
			create_cover_image();
			create_track_label();

			c.playback_status += on_playback_status_change;
			c.playback_current_id += on_playback_current_id;
			c.playback_playtime += on_playback_playtime;
		}

		private Gtk.Button create_playback_button(weak string s) {
			Gtk.Button button = new Gtk.Button();

			button.relief = Gtk.ReliefStyle.NONE;
			button.image = new Gtk.Image.from_stock(s, Gtk.IconSize.SMALL_TOOLBAR);

			pack_start(button, false, false, 0);

			return button;
		}

		private void create_seekbar() {
			Gtk.VBox vbox = new Gtk.VBox(false, 0);

			_time_slider = new Gtk.HScale.with_range(0, 1, 0.01);

			_time_slider.digits = 1;
			_time_slider.draw_value = false;
			_time_slider.width_request = 130;
			_time_slider.sensitive = false;

			_time_slider.button_press_event += on_time_slider_press;
			_time_slider.button_release_event += on_time_slider_release;

			vbox.pack_start(_time_slider, true, true, 0);

			_time_label = new Gtk.Label("");
			vbox.pack_start(_time_label, true, true, 0);

			pack_start(vbox, false, true, 0);
		}

		[InstanceLast]
		private bool on_time_slider_press(Gtk.Widget widget, Gdk.Event e) {
			_seek = true;
			_time_slider.motion_notify_event += on_time_slider_motion_notify;

			return false;
		}

		[InstanceLast]
		private bool on_time_slider_release(Gtk.Widget widget, Gdk.Event e) {
			weak Gtk.HScale scale = (Gtk.HScale) widget;
			Client c = Client.instance();

			double percent = scale.get_value();
			uint pos = (uint)(_duration * percent);

			c.xmms.playback_seek_ms(pos);

			_time_slider.motion_notify_event -= on_time_slider_motion_notify;

			_seek = false;

			return false;
		}

		[InstanceLast]
		private bool on_time_slider_motion_notify(Gtk.Widget widget, Gdk.Event e) {
			weak Gtk.HScale scale = (Gtk.HScale) widget;

			double percent = scale.get_value();
			uint pos = (uint)(_duration * percent);

			update_time(pos);

			return false;
		}

		private void create_cover_image() {
			_coverart = new Gtk.Image.from_stock(
				Gtk.STOCK_CDROM, Gtk.IconSize.LARGE_TOOLBAR
			);

			pack_start(_coverart, false, true, 4);
		}

		private void create_track_label() {
			_track_label = new Gtk.Label(
				GLib._("No Track")
			);

			pack_start(_track_label, false, true, 4);
		}

		private void on_playback_current_id(Client c, uint mid) {
			c.xmms.medialib_get_info(mid).notifier_set(
				on_medialib_get_info
			);
		}

		private void update_time(uint pos) {
			/* This is a HACK to circumvent a bug in XMMS2 */
			if (_status == Xmms.PlaybackStatus.STOP) {
				pos = 0;
			}

			if (_duration > 0) {
				double percent = (double) pos / (double) _duration;
				_time_slider.set_value(percent);
				_time_slider.set_sensitive(true);
			} else {
				_time_slider.set_value(0);
				_time_slider.set_sensitive(false);
			}

			uint dur_min, dur_sec, pos_min, pos_sec;
			string info;

			dur_min = _duration / 60000;
			dur_sec = (_duration % 60000) / 1000;

			pos_min = pos / 60000;
			pos_sec = (pos % 60000) / 1000;

			info = GLib.Markup.printf_escaped(
				GLib._("%3d:%02d  of %3d:%02d"),
				pos_min, pos_sec, dur_min, dur_sec
			);

			_time_label.set_markup(info);
		}

		private void on_playback_playtime(Client c, uint pos) {
			if (_seek == false) {
				update_time(pos);
			}
		}

		[InstanceLast]
		private void on_medialib_get_info(Xmms.Result #res) {
			weak string artist, title, album, cover;
			string info;
			int id;
			int duration, dur_min, dur_sec, pos;

			res.get_dict_entry_int("id", out id);
			if (!res.get_dict_entry_int("duration", out duration)) {
				duration = 0;
			}


			if (!res.get_dict_entry_string("artist", out artist)) {
				artist = GLib._("Unknown");
			}

			if (!res.get_dict_entry_string("title", out title)) {
				title = GLib._("Unknown");
			}

			if (!res.get_dict_entry_string("album", out album)) {
				album = GLib._("Unknown");
			}

			if (!res.get_dict_entry_string("picture_front", out cover)) {
				_coverart.set_from_stock(
					Gtk.STOCK_CDROM, Gtk.IconSize.LARGE_TOOLBAR
				);
			} else {
				Client c = Client.instance();

				c.xmms.bindata_retrieve(cover).notifier_set(
					on_bindata_retrieve
				);
			}

			info = GLib.Markup.printf_escaped(
				GLib._("<b>%s</b>\n" +
				"<small>by</small> %s <small>from</small> %s"),
				title, artist, album
			);

			_track_label.set_markup(info);
			_duration = duration;
		}

		[InstanceLast]
		private void on_bindata_retrieve(Xmms.Result #res) {
			weak uchar[] data;

			if (res.get_bin(out data)) {
				Gdk.PixbufLoader loader;
				weak Gdk.Pixbuf pixbuf;

				loader = new Gdk.PixbufLoader();
				try {
					loader.write(data);
					loader.close();
				} catch (GLib.Error ex) {
					GLib.stdout.printf("never happens, should default to CDROM icon\n");
				}

				pixbuf = loader.get_pixbuf();
				pixbuf = pixbuf.scale_simple(32, 32, Gdk.InterpType.BILINEAR);
				_coverart.set_from_pixbuf(pixbuf);
			}
		}


		[InstanceLast]
		private void on_media_play(Gtk.Button btn) {
			Client c = Client.instance();

			if (_status == Xmms.PlaybackStatus.PLAY) {
				c.xmms.playback_pause();
			} else {
				c.xmms.playback_start();
			}
		}

		[InstanceLast]
		private void on_media_stop(Gtk.Button btn) {
			Client c = Client.instance();
			c.xmms.playback_stop();
		}

		[InstanceLast]
		private void on_media_prev(Gtk.Button btn) {
			Client c = Client.instance();
			c.xmms.playlist_set_next_rel(-1);
			c.xmms.playback_tickle();
		}

		[InstanceLast]
		private void on_media_next(Gtk.Button btn) {
			Client c = Client.instance();
			c.xmms.playlist_set_next_rel(1);
			c.xmms.playback_tickle();
		}

		[InstanceLast]
		private void on_playback_status_change(Client c, int status) {
			Gtk.Image image;

			_status = status;

			if (_status != Xmms.PlaybackStatus.PLAY) {
				image = new Gtk.Image.from_stock(
					Gtk.STOCK_MEDIA_PLAY,
					Gtk.IconSize.SMALL_TOOLBAR
				);
				play_pause.set_image(image);
			} else {
				image = new Gtk.Image.from_stock(
					Gtk.STOCK_MEDIA_PAUSE,
					Gtk.IconSize.SMALL_TOOLBAR
				);
				play_pause.set_image(image);
			}

			if (_status == Xmms.PlaybackStatus.STOP) {
				update_time(0);
			}
		}
	}
}
