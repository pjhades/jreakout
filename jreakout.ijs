require 'gl2'
require 'trig'
require 'format/printf'
coinsert 'jgl2'

FPS =: 60
DELAY =: %FPS
NB. window width, height
W =: 500
H =: 300
NB. brick width, height
BW =: 50
BH =: 20
NB. paddel width, height
PW =: 100
PH =: 5
NB. ball radius
R =: 5
D =: +:R

delay =: 6!:3
cross =: (-/ . *)@:,:
dot =: +/@:*
dist =: %:@:+/@:*:@:-
len =: %:@+/@:*:

clamp =: dyad define
  'xmin ymin xmax ymax' =. ,>x
  'x y' =. y
  (xmin>.x<.xmax),(ymin>.y<.ymax)
)

set_timer =: verb define
  wd 'timer ',(":y),';'
)

set_form_timer =: verb define
  wd 'ptimer ',(":y),';'
)

draw_win =: verb define
  wd 'pc game;'
  wd 'cc canvas isigraph flush;'
  wd 'setp wh ',(":W),' ',(":H),';'
  wd 'pshow;'
)

game_close =: verb define
  wd 'psel game;'
  wd 'pclose;'
  set_timer 0
)

draw_ball =: verb define
  glbrush glrgb 255 0 0
  glellipse (ball-R),D,D
)

draw_brick =: verb define
  glbrush glrgb 0 190 250
  glrect y,BW,BH
)

draw_pad =: verb define
  glbrush glrgb 100 100 100
  glrect pad,(H-PH),PW,PH
)

draw_frame =: verb define
  glclear ''
  draw_brick"1 bricks
  draw_pad ''
  draw_ball ''
)

draw_result =: verb define
  glrgb 255 0 0
  draw_frame ''
  glfont '"Arial" 30'
  gltextcolor ''
  gltextxy ((-:W)-50),-:H
  gltext >lost{'You win!';'You lose!'
)

paint_handler =: draw_frame`draw_result

game_canvas_paint =: verb define
  paint_handler@.game_end ''
)

game_timer =: verb define
  pad_d =: 0
  set_form_timer 0
)

game_canvas_char =: verb define
  select. key =: a.i.sysdata
    case. 239 160 146 do.
      pad_d =: _1
    case. 239 160 148 do.
      pad_d =: 1
  end.
  set_form_timer 370
)

bounce =: verb define
  diff =. ({.ball)-pad
  left =. diff<:-:PW
  x =. diff<.PW-diff
  angle =. 1r6p1 + (1r2p1-1r6p1) * x%-:PW
  angle =. (1p1&+@:-)^:left angle
  (cos angle),-sin angle
)

NB. Compute intersect of a ray and an axis-aligned segment.
NB. @x: ray endpoint ; direction vector
NB. @y: two endpoints of the axis-aligned segment
NB. Return coordinate if they intersect or coincide.
intersect =: dyad define
  'p d' =. x
  's1 s2' =. y

  s =. s2-s1
  c1 =. d cross s
  c2 =. (s1-p) cross s

  if. (c1=0)*.(c2=0) do.
    NB. collinear
    u1 =. ((s1-p) dot d) % (d dot d)
    u2 =. (((s1+s)-p) dot d) % (d dot d)
    'u1 u2' =. (u1<.u2),(u1>.u2)
    if. u2<0 do.
      _ _ return.
    elseif. u1<0 do.
      p+u2*d return.
    else.
      p+u1*d return.
    end.
  elseif. c1=0 do.
    NB. parallel
    _ _ return.
  else.
    NB. intersect
    u =. c2%c1
    v =. ((s1-p) cross d)%c1
    if. (u>:0)*.(v>:0)*.(v<:1) do.
      p+u*d return.
    else.
      _ _ return.
    end.
  end.
)

NB. Check if the ball will hit a brick.
NB. @y: brick position
NB. We check against the 4 edges of the brick.
NB. The return value is hit_result ; hit_point where
NB. hit_result is encoded as a bit array:
NB.    bit 3 2 1 0
NB.   name L R U D
NB. where the bits indicate that the ball hits
NB. a brick on left, right, top and bottom respectively.
NB. hit_point is the position of the hit.
check_one_brick =: verb define
  'bx by' =. y

  NB. edges
  right =. ((bx+BW+R),by-R) ; (bx+BW+R),by+BH+R
  left  =. ((bx-R),by-R)    ; (bx-R),by+BH+R
  down  =. ((bx-R),by+BH+R) ; (bx+BW+R),by+BH+R
  up    =. ((bx-R),by-R)    ; (bx+BW+R),by-R

  all =. (ball;d) intersect"1 1 right,left,down,:up
  dists =. ball dist"1 1 all
  hit_result =. (= <./) dists
  hit_point  =. dists ((i. <./)@:[ { ]) all
  hit_result ; hit_point
)

NB. Check against all bricks to see if any is hit.
NB. Return remaining bricks ; hit result ; hit point
check_bricks =: verb define
  all =. check_one_brick"1 bricks
  dists =. ball dist"1 1 >1{"1 all
  closest =. <./dists

  if. closest=_ do.
    y;0 0 0 0;_ _ return.
  end.

  remaining =. (I.-.closest=dists){bricks
  hits =. (I.closest=dists){all
  hit_result =. |:+./>{.|:hits
  hit_point  =. {:({.I.closest=dists){all

  remaining ; hit_result ; hit_point
)

check_walls =: verb define
  left  =. (R,R)        ; R,(H-R)-PH
  right =. ((W-R),R)    ; (W-R),(H-R)-PH
  up    =. (R,R)        ; (W-R),R
  down  =. (R,(H-R)-PH) ; (W-R),(H-R)-PH

  all =. (ball;d) intersect"1 1 left,right,up,:down
  match =. -. all (-:"1) _ _
  hits =. (I.match){all
  hit_point  =. ({.I.match){all
  match ; hit_point
)

predict =: verb define
  'remaining brick_result brick_point' =. check_bricks ''
  'wall_result wall_point' =. check_walls ''

  hit_pad =. +./@:*.&0 0 0 1
  check_lost =: 0

  if. brick_point-:_ _ do.
    NB. only hit wall
    'hit_result hit_point' =: wall_result;wall_point
    check_lost =: hit_pad hit_result
  end.

  dist_to_brick =. brick_point dist ball
  dist_to_wall  =. wall_point  dist ball

  if. dist_to_brick<dist_to_wall do.
    NB. hit brick first
    bricks_remaining =: remaining
    'hit_result hit_point' =: brick_result;brick_point
  elseif. dist_to_brick>dist_to_wall do.
    NB. hit wall first
    'hit_result hit_point' =: wall_result;wall_point
    check_lost =: hit_pad hit_result
  else.
    NB. hit both
    bricks_remaining =: remaining
    hit_result =: brick_result+.wall_result
    hit_point =: brick_point
    check_lost =: hit_pad hit_result
  end.

  assert hit_point~:_ _

  frame =: <.(hit_point dist ball)%v
)

do_move =: verb define
  ball =: ball + v*d
  pad =: pad + pad_v*pad_d
  pad =: 0>.pad<.W-PW
  glpaint ''
  frame =: <:frame
  resolve =: frame=0
)

done =: verb define
  glpaint ''
  game_canvas_char =: ]
  set_timer 0
)

do_resolve =: verb define
  if. check_lost do.
    lost =: -. (pad<:{.hit_point)*.((pad+PW)>:{.hit_point)
  end.

  if. lost +. 0=#bricks_remaining do.
    game_end =: 1
    done ''
  else.
    if. 1=3{hit_result do.
      d =: bounce ''
      NB.d =: d*1 _1
    elseif. -. 0 0-:0 1{hit_result do.
      d =: d*_1 1
    elseif. 1=2{hit_result do.
      d =: d*1 _1
    end.

    ball =: (((R+1),R+1);((W-R)-1),(H-R)-1) clamp hit_point+d
    bricks =: bricks_remaining
    glpaint ''
    predict ''
    resolve =: frame=0
  end.
)

do_frame =: do_move`do_resolve

timer_handler =: verb define
  do_frame@.resolve ''
)

init =: verb define
  x =. BW * i.<.W%BW
  y =. BH * i.<.(<.H%3)%BH
  bricks =: ,/ x (,"0/) y
  bricks_remaining =: bricks
  pad =: <.W%3
  NB. minus 1 to avoid hitting bottom line at the beginning
  ball =: R + (pad+?(PW-D)) , ((H-PH)-D)-1
  v =: 3
  pad_v =: 3
  pad_d =: 0
  d =: bounce ''
  lost =: 0
  game_end =: 0
  resolve =: 0
  frame =: _
  sys_timer_z_ =: ('timer_handler','_',(>coname''),'_')~
  draw_win ''
)

main =: verb define
  NB. close previously created win if any
  game_close^:wdisparent ''
  init ''
  glpaint ''
  predict ''
  set_timer DELAY*1000
)

main ''
