# Simple breakout game written in J

Collision detection between the ball and the two upper corners of the paddle
is done in a very brief (bad) way: the paddle hits the ball only if:

- `ball.lowest_point.y == paddle.upper_edge.y`
- `ball.lowest_point.x >= paddle.top_left_corner.x && ball.lowest_point.x <= paddle.top_right_corner.x`

There may be unknown bugs.
