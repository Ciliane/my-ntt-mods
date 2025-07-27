#define init
  global.options = null;
  if (fork()) {
    options_load();
    exit;
  }

  global.fonts = {
    "M1": fntM1,
    "m1": fntM1,
    "small": fntSmall,
    "chat": fntChat,
    "none": -1
  };

  chat_comp_add("ftloop", "<loop> sets the end loop, where FT will be disabled");
  chat_comp_add("fttipfont", "<font> sets the font to use for FT's tips");

  global.generating = false;

#macro OPT global.options;
#macro OPT_LOADED !is_undefined(global.options);
#macro OPT_FILE "options.json";

#define chat_command(_cmd, _arg)
  if (_cmd == "ftloop") {
    if (_arg == "") {
      trace("Specify an end loop number, where FT will be disabled. Set -1 for no limit.");
      return true;
    }

    var _loop = real(_arg);
    OPT.end_loop = _loop;
    if (_loop <= -1) {
      trace("Fast Transitions won't stop at any loop.");
    } else {
      trace(`Fast Transitions will stop at L${_loop}.`);
    }
    options_save();
    return true;
  }

  if (_cmd == "fttipfont") {
    if (!lq_exists(global.fonts, _arg)) {
      trace("Specify a font that will be used for FT's loading screen tip popup. Available fonts: M1, small, chat, none");
      return true;
    }

    OPT.tip_font = _arg;
    trace(`Fast Transitions tip font changed to ${_arg}.`);
    options_save();
    return true;
  }

#define game_start
  global.generating = false;

#define step
  if (OPT_LOADED && OPT.end_loop > -1 && GameCont.loops >= OPT.end_loop) {
    exit;
  }

  /*
    This comment explains all of the black magic involved in this section

    "endgame" is used as a countdown timer before the portal's animation moves
    on to the next stage. It's always 100 if the portal hasn't been touched

    Portals spawn a PortalClear and a PortalShock at the end of their spawning
    animation, which destroy walls and open chests respectively. In case the
    player manages to touch the portal right after it was created, we have to
    hurry that process up by performing ev_animation_end and performing manual
    collisions for the PortalShock

    Once endgame becomes 0 or lower, portal will begin its closing animation. We
    set endgame to 0 and perform portal's step manually to begin the closing
    stage instantly. The level will end once the closing animation
    finishes, which we will force by performing ev_animation_end eventually

    Rads only get collected by touching a portal if their speed is 0. This
    auto-collect also pulls weapons in, but only at range where portals would
    attract them normally (except for on 7-3 or 0-1). Call GameCont's step to
    ensure level-up from auto-collected rads
  */
  with (instances_matching_lt(Portal, "endgame", 100)) {
    if (sprite_index == sprPortalSpawn || sprite_index == sprBigPortalSpawn) {
      event_perform(ev_other, ev_animation_end);
      with (PortalShock) {
        with (instances_matching([chestprop, RadChest], "", undefined)) {
          if (place_meeting(x, y, other)) {
            event_perform(ev_collision, PortalShock);
            if ("my_health" in self) {
              event_perform(ev_step, ev_step_begin);
            }
          }
        }
      }
    }

    endgame = 0;
    event_perform(ev_step, 0);

    with (Pickup) {
      if (instance_is(self, WepPickup) &&
          distance_to_object(other) > 95 &&
          other.object_index != BigPortal) {
        continue;
      }

      x = other.x;
      y = other.y;
      speed = 0;
      event_perform(ev_collision, Portal)
    }
    with (GameCont) {
      event_perform(ev_step, ev_step_normal);
    }

    event_perform(ev_other, ev_animation_end);
  }

  script_bind_end_step(end_step, 0);

#define end_step
  instance_destroy();

  // end_step is slightly better timing to catch freshly created GenConts
  if (instance_exists(GenCont)) {
    if (!global.generating) {
      global.generating = true;
      generation_start();
    }
  } else if (global.generating) {
    global.generating = false;
    generation_end();
  }

#define generation_start
  if (GameCont.area != 106) {
    if (OPT_LOADED && (OPT.tip_font != "none" && OPT.tip_font != -1)) {
      with (instance_create(0, 0, CustomObject)) {
        depth = -1600;

        mytext = GenCont.tip;
        font = lq_get(global.fonts, OPT.tip_font);
        blink = 10;
        alarm0 = 45;

        on_step = tip_step;
        on_draw = tip_draw;
      }
    }

    // GameCont's alarm0 creates the crown. Needs to be hurried up so that IDPD
    // properly spawn on 1-1 L0, when starting with a crown
    with (GameCont) {
      if (alarm0 > -1) {
        event_perform(ev_alarm, 0);
        alarm0 = -1;
      }
    }

    gen_force_instant();
  }

#define generation_end
  with (Spiral) {
    repeat (12) {
      if (instance_exists(self)) {
        event_perform(ev_step, 0);
      }
    }
  }

  with (Player) {
    var _sx = view_xview[index];
    var _sy = view_yview[index];
    var _shift_dir = point_direction(_sx, _sy, x, y);
    var _shift_dist = point_distance(_sx, _sy, x, y);

    var _shake = UberCont.opt_shake;
    UberCont.opt_shake = 1;

    // Thanks to Yokin (view_shift from scripts.gml)
    gunangle = _shift_dir;
    weapon_post(0, _shift_dist * current_time_scale, 0);

    UberCont.opt_shake = _shake;
  }

#define tip_step
  if (alarm0 && !--alarm0) {
    visible = !visible;
    if (--blink) {
      alarm0 = 2;
    } else {
      instance_destroy();
    }
  }

#define tip_draw
  draw_set_font(font);
  draw_set_halign(fa_center);
  draw_set_valign(fa_center);
  var _draw_x = (view_xview_nonsync + game_width / 2);
  var _draw_y = (view_yview_nonsync + game_height / 2 - 31);
  draw_text_nt(_draw_x, _draw_y, "@s" + mytext);

#define gen_force_instant
  for (var i = 0; instance_number(Floor) < GenCont.goal && i < 100; i++) {
    with (FloorMaker) {
      event_perform(ev_step, 0);
    }
  }
  with (FloorMaker) {
    instance_destroy();
  }

  // Running floormakers' step manually results in duplicate floors
  // so some cleanup is needed (thanks torcho)
  with (Floor) {
    var _f = instance_place(x, y, Floor);
    if (_f && id > _f.id) {
      instance_delete(self);
    }
  }

  with (GenCont) {
    event_perform(ev_alarm, 2);
    event_perform(ev_alarm, 0);
    event_perform(ev_alarm, 1);
    instance_destroy();
  }

#define options_load
  wait file_load(OPT_FILE);
  if (file_exists(OPT_FILE)) {
    global.options = json_decode(string_load(OPT_FILE));
  } else {
    global.options = {
      end_loop: -1,
      tip_font: -1,
    };
    options_save();
  }

#define options_save
  string_save(json_encode(global.options), OPT_FILE);
