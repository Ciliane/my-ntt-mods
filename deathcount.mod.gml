#define init
  global.deaths = array_create(maxp, 0);
  global.dead_sprites = array_create(maxp, mskNone);
  global.tainted_spirit_color = c_black;

  global.players = 0;
  for (var i = 0; i < maxp; i++) {
    if (player_is_active(i)) {
      global.players++;
    }
  }

  chat_comp_add("rest", "kills you and bypasses deathcount mod's immortality");

#define game_start
  global.deaths = array_create(maxp, 0);
  global.dead_sprites = array_create(maxp, mskNone);

#define chat_command(_command, _arg, _index)
  if (_command == "rest") {
    var _p = player_find(_index);
    with (Player) {
      lasthit = [(instance_exists(_p) ? _p.spr_idle : spr_idle), "YOU"];
      instance_destroy();
    }
    return true;
  }

#define step
  with (Player) {
    var _have_spirit = (canspirit && skill_get(mut_strong_spirit));
    var _chicken = (race == "chicken" && bleed + current_time_scale < 120);
    if (candie && my_health <= 0 && !_chicken &&
        spiriteffect <= 0 && !_have_spirit) {
      global.deaths[index]++;
      spiriteffect = 4;

      if (race == "chicken") {
        var _recover = min(chickendeaths, 2);
        chickendeaths -= _recover;
        maxhealth += _recover;
      }

      sound_play_hit_big(sndStrongSpiritLost, 0);
      with (instance_create(x, y, StrongSpirit)) {
        creator = other;
        image_blend = global.tainted_spirit_color;
      }
    }

    if (global.deaths[index] > 0) {
      var _pops = instances_matching(StrongSpirit, "creator", id);
      with (_pops) {
        if (array_length(_pops) == 1 &&
            sprite_index == sprStrongSpirit &&
            image_index + image_speed >= sprite_get_number(sprite_index)) {
          image_index = 0;
          sprite_index = sprStrongSpiritRefill;
          image_blend = global.tainted_spirit_color;
        }
      }
      if (visible && !_have_spirit && array_length(_pops) == 0) {
        script_bind_draw(tainted_spirit_draw, -7, id);
      }
    }
  }

#define tainted_spirit_draw(_target)
  instance_destroy();
  with (_target) {
    draw_sprite_ext(sprHalo, 0, x, y + sin(wave / 10), 1, 1, 0, global.tainted_spirit_color, 1);
  }

#define draw_pause
  draw_counter(true);

#define draw_gui
  if (instance_exists(Menu) || instance_exists(Campfire)) {
    exit;
  }
  if (instance_exists(TopCont) && TopCont.dead) {
    draw_counter_endscreen();
  } else {
    draw_counter(false);
  }

#define draw_counter(_paused)
  for (var i = 0; i < maxp; i++) {
    if (!player_is_active(i) || global.deaths[i] == 0) {
      continue;
    }

    var _counter_x = 11 + (_paused ? view_xview_nonsync : 0);
    var _counter_y = 55 + (_paused ? view_yview_nonsync : 0);

    var _player_instance = player_find(i);
    if (instance_exists(_player_instance)) {
      var _r = _player_instance.race;
      if (_r == "venuz" || _r == "horror" || _r == "bigdog") {
        global.dead_sprites[i] = sprHalo;
      } else {
        global.dead_sprites[i] = _player_instance.spr_dead;
      }
    }

    draw_set_projection(2, i);
    if (global.dead_sprites[i] != sprHalo) {
      draw_sprite_ext(global.dead_sprites[i], sprite_get_number(global.dead_sprites[i]) - 1, _counter_x, _counter_y, 1, 1, 0, c_gray, 1);
    }

    draw_set_halign(fa_center);
    draw_set_valign(fa_center);
    draw_text_nt(_counter_x, _counter_y, string(global.deaths[i]));

    if (global.dead_sprites[i] == sprHalo) {
      draw_sprite_ext(sprHalo, 0, _counter_x, _counter_y + 7 + sin(current_frame / 10), 1, 1, 0, global.tainted_spirit_color, 1);
    }
  }

#define draw_counter_endscreen
  var _endscreen_string = counter_endscreen_string();

  var _splat_frame = clamp(floor(TopCont.gameovertime) - 20, 0, 2);
  if (_splat_frame > 0) {
    var _splat_x = game_width / 2 - 51;
    var _splat_y = game_height / 2 + 20;
    draw_sprite(sprScoreSplat, _splat_frame, _splat_x, _splat_y);

    draw_set_valign(fa_center);
    draw_set_halign(fa_right);
    draw_text_nt(_splat_x + 13, _splat_y, "D");

    draw_sprite_ext(sprHalo, 0, game_width / 2 - 51 + 8, game_height / 2 + 24 + sin(current_frame / 10), 1, 1, 0, global.tainted_spirit_color, 1);

    draw_set_halign(fa_left);
    draw_text_nt(_splat_x + 17, _splat_y, _endscreen_string);
  }

#define counter_endscreen_string
  if (global.players == 1) {
    return string(global.deaths[0]);
  }
  var _endscreen_string = "";
  for (var i = 0; i < maxp; i++) {
    if (player_is_active(i)) {
      _endscreen_string += `@(color:${player_get_color(i)})${global.deaths[i]}@w+`;
    }
  }
  return string_copy(_endscreen_string, 1, string_length(_endscreen_string) - 3);

#define cleanup
  chat_comp_remove("rest");

