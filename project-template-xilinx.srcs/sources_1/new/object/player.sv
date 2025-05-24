// 足球运动员模块
module player
#(parameter PLAYER_INIT_X = 0, PLAYER_INIT_Y = 0, PLAYER_INIT_V = 0, PLAYER_INIT_ANGLE = 0)
(
    input player_game_clk,           //和游戏时钟频率相同
    input rst, 
    //输入，用于控制。 action_HFSM通过这4个信号进行控制
    input A_enable,
    input A_signal,
    input W_enable,
    input W_signal,
    //输出，用于 1.渲染  2.模块之间交互 3.AI参数
    input reg hold,    // 当输出hold信号时，持续2个周期，外部捕捉到这个信号，交给仲裁器
    output reg [15:0] pos_x,
    output reg [15:0] pos_y,
    output reg [7:0] angle,
    output reg [7:0] speed,
    output reg [7:0] anim_stat  //用于渲染不同的运动员动作
    // 迈开腿这样的状态机切换频率，应该和人物的速度挂钩
);
    /****************   坐标计算  *******************/
    position_caculator #(.INIT_X(PLAYER_INIT_X), .INIT_Y(PLAYER_INIT_Y))u_position_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .in_angle(angle),
        .in_speed(speed),
        .out_x(pos_x),
        .out_y(pos_y)
    );

    /***************** 速度计算****************/
    speed_caculator #(.V_INIT(PLAYER_INIT_V))u_speed_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .enable(A_enable),
        .signal(A_signal),
        .speed(speed)
    );

    /**************** 角度计算 *****************/
    angle_caculator #(.INIT_ANGLE(PLAYER_INIT_ANGLE))u_angle_cacluator(
        .game_clk(player_game_clk),
        .rst(rst),
        .enable(W_enable),
        .signal(W_signal),
        .angle(angle)
    );
endmodule