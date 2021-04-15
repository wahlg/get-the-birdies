# Calls methods needed for game to run properly
def tick args
  tick_instructions args
  defaults args
  render args
  calc args
  input args
end

# initialization happens the first frame
def defaults args
  args.state.gravity                  = -0.3
  args.state.cat_jump_power           = 10
  args.state.cat_jump_power_duration  = 10
  args.state.cat_max_run_speed        = 10
  args.state.cat_speed_slowdown_rate  = 0.9
  args.state.cat_acceleration         = 1
  args.state.tick_count               = args.state.tick_count
  args.state.ground_top               = 128
  args.state.cat.x                  ||= 0
  args.state.cat.y                  ||= args.state.ground_top
  args.state.cat.w                  ||= 108.5 # png cat dimension = 31 X 20
  args.state.cat.h                  ||= 70
  args.state.cat.dy                 ||= 0
  args.state.cat.dx                 ||= 0
  args.state.cat.direction          ||= 1
  args.state.cat.jump_angle         ||= 20
  args.state.max_num_birds          ||= 5
  args.state.bird_w                   = 52.2 # png bird dimensions = 174 X 96
  args.state.bird_h                   = 28.8
  args.state.bird_speed               = 4
  args.state.bird_x_max             ||= args.grid.w - args.state.bird_w
  args.state.bird_x_min             ||= 0
  args.state.bird_y_max             ||= args.grid.h - args.state.bird_h
  args.state.bird_y_min             ||= args.state.ground_top
  args.state.birds                  ||= []
  args.state.game_over_at           ||= 0
  args.state.best_time              ||= nil
  args.state.last_time              ||= nil
  if args.state.tick_count == 0
    args.state.round_over = false
  end
end

# outputs objects onto the screen
def render args
  render_score args

  # background
  args.outputs.background_color = [70, 211, 250]

  # ground
  args.outputs.solids << [0, 0, args.grid.w, args.state.ground_top, 26, 150, 15]

  # cat
  cat_angle = args.state.cat.y > args.state.ground_top ? args.state.cat.jump_angle : 0
  if (args.state.cat.dy > 0 && args.state.cat.direction < 0) || (args.state.cat.dy < 0 && args.state.cat.direction > 0)
    cat_angle *= -1
  end
  args.outputs.sprites << [
    args.state.cat.x,
    args.state.cat.y,
    args.state.cat.w,
    args.state.cat.h,
    args.state.cat.direction > 0 ? 'sprites/cat-right.png' : 'sprites/cat-left.png',
    cat_angle
  ]

  # birds
  args.outputs.sprites << args.state.birds.map do |bird|
    render_attrs = {
      path: 'sprites/bird-right-flap-1.png'
    }
    if bird[:dead]
      render_attrs[:flip_vertically] = true
    else
      if (args.state.tick_count % 40) > 20
        render_attrs[:path] = 'sprites/bird-right-flap-2.png'
      end
      if bird[:dx] < 0
        render_attrs[:flip_horizontally] = true
      end
    end
    bird.merge(render_attrs)
  end
end

def time_str time
  return "--" if !time
  '%.2fs' % (time / 60)
end

def render_score args
  args.outputs.labels << [
    10,
    710,
    "Birds remaining: #{args.state.birds.reject { |b| b[:dead] }.size}"
  ]

  args.outputs.labels << [
    1070,
    710,
    "Best time: #{time_str args.state.best_time}"
  ]

  args.outputs.labels << [
    860,
    710,
    "Last time: #{time_str args.state.last_time}"
  ]
end

# Performs calculations to move objects on the screen
def calc args
  calc_cat args
  calc_birds args
end

def calc_cat args
  # Since velocity is the change in position, the change in x increases by dx. Same with y and dy.
  args.state.cat.x  += args.state.cat.dx
  args.state.cat.y  += args.state.cat.dy

  args.state.cat.dy += args.state.gravity

  args.state.cat.x  = args.state.cat.x.greater(0).lesser(args.grid.w - args.state.cat.w)
  args.state.cat.y  = args.state.cat.y.greater(args.state.ground_top)

  # cat is not falling if it is located on the top of the ground
  args.state.cat.falling = false if args.state.cat.y == args.state.ground_top
  args.state.cat.rect = [args.state.cat.x, args.state.cat.y, args.state.cat.h, args.state.cat.w]
end

def calc_birds args
  # If all birds are gone, add back birds.
  if args.state.birds.size == 0
    reset_round args
  end

  args.state.birds.reject { |b| b[:dead] }.each do |h|
    h[:rect] = [h[:x], h[:y], h[:w], h[:h]]

    if h[:rect].intersect_rect?(args.state.cat.rect)
      h[:dead] = true
      h[:dy]   = args.state.bird_speed * -1
      h[:dx]   = 0
    else
      if h[:x] == args.state.bird_x_max || h[:x] == args.state.bird_x_min
        h[:dx] = h[:dx] * -1
      end
      if h[:y] == args.state.bird_y_max || h[:y] == args.state.bird_y_min
        h[:dy] = h[:dy] * -1
      end
    end
  end

  args.state.birds.each do |h|
    h[:x] = (h[:x] + h[:dx]).lesser(args.state.bird_x_max).greater(args.state.bird_x_min)
    h[:y] = (h[:y] + h[:dy]).lesser(args.state.bird_y_max).greater(args.state.bird_y_min)
  end

  args.state.birds = args.state.birds.reject do |b|
    b[:dead] && b[:y] == args.state.bird_y_min
  end

  if args.state.birds.reject { |b| b[:dead] }.size == 0 && !args.state.round_over
    calc_score args
    args.state.round_over = true
  end
end

def calc_score args
  args.state.last_time = args.state.tick_count - args.state.game_over_at
  if !args.state.best_time.nil?
    args.state.best_time = args.state.last_time.lesser(args.state.best_time)
  else
    args.state.best_time = args.state.last_time
  end
  args.state.game_over_at = args.state.tick_count
end

def reset_round args
  args.state.max_num_birds.times do
    args.state.birds << {
      x: (0..(args.grid.w - args.state.bird_w)).to_a.sample,
      y: (args.state.ground_top..(args.grid.h - args.state.bird_h)).to_a.sample,
      w: args.state.bird_w,
      h: args.state.bird_h,
      dx: args.state.bird_speed * [1, -1].sample,
      dy: args.state.bird_speed * [1, -1].sample,
      dead: false
    }
  end
  args.state.round_over = false
end

# Processes input from the user to move the cat
def input args
  if args.inputs.keyboard.space
    args.state.cat.jumped_at ||= args.state.tick_count

    # if the time that has passed since the jump is less than the cat's jump duration and
    # the cat is not falling
    if args.state.cat.jumped_at.elapsed_time < args.state.cat_jump_power_duration && !args.state.cat.falling
      args.state.cat.dy = args.state.cat_jump_power
    end
  end

  # if the space bar is in the "up" state (or not being pressed down)
  if args.inputs.keyboard.key_up.space
    args.state.cat.jumped_at = nil
    args.state.cat.falling = true
  end

  if args.inputs.keyboard.left
    args.state.cat.dx -= args.state.cat_acceleration
    args.state.cat.dx = args.state.cat.dx.greater(-args.state.cat_max_run_speed)
    args.state.cat.direction = -1
  elsif args.inputs.keyboard.right
    args.state.cat.dx += args.state.cat_acceleration
    args.state.cat.dx = args.state.cat.dx.lesser(args.state.cat_max_run_speed)
    args.state.cat.direction = 1
  else
    args.state.cat.dx *= args.state.cat_speed_slowdown_rate
  end
end

def tick_instructions args, y = 115
  args.outputs.debug << [0, y - 50, 1280, 60, 26, 150, 15].solid
  args.outputs.debug << [640, y, "Use LEFT and RIGHT arrow keys to move and SPACE to jump.", 1, 1, 255, 255, 255].label
end
