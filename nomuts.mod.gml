#define step
  script_bind_end_step(end_step, 0);

#define end_step
  instance_destroy();
  GameCont.skillpoints = 0;
