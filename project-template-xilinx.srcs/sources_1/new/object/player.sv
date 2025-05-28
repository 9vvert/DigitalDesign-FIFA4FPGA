// 足球运动员模块
import type_declare::PlayerInfo, type_declare::MoveControl;
module player
#(parameter PLAYER_INIT_X = 0, PLAYER_INIT_Y = 0, PLAYER_INIT_V = 0, PLAYER_INIT_ANGLE = 0, PLAYER_INDEX=1)
(
    input player_game_clk,           //和游戏时钟频率相同
    input rst, 
    //cmd输入的信号，但是不一定有效，需要通过selected来决定是否使用
    input [7:0] cmd_left_angle,
    input [7:0] cmd_right_angle,
    input [7:0] cmd_action_cmd,
    //输出，用于 1.渲染  2.模块之间交互 3.AI参数
    input hold,    // 当输出hold信号时，持续2个周期，外部捕捉到这个信号，交给仲裁器
    input selected,                 // 自己是否被选中，如果是的话，一直为高。
    // input pre_switch_target,        // 自己是否为预切换的对象

    //输入其它对象的信息
    input BallInfo ball_info,
    //输出自己的信息
    output PlayerInfo self_info,
    output ConstrainedInit out_const,
    output FreeInit out_free
);
    reg [11:0] pos_x;
    reg [11:0] pos_y;
    reg [7:0] speed;
    reg [7:0] angle;
    wire [3:0] anim_stat;

    always_comb begin
        self_info.index = PLAYER_INDEX;
        self_info.anim_stat = anim_stat; 
        self_info.x = pos_x;
        self_info.y = pos_y;
        self_info.speed = speed;
        self_info.angle = angle;
        
    end    
    MoveControl move_ctrl;
    /******************* 物理引擎  *********************/
    // 坐标计算
    position_caculator #(.INIT_X(PLAYER_INIT_X), .INIT_Y(PLAYER_INIT_Y))u_position_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .in_angle(angle),
        .in_speed(speed),
        .out_x(pos_x),
        .out_y(pos_y)
    );

    // 速度计算
    speed_caculator #(.V_INIT(PLAYER_INIT_V))u_speed_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .enable(move_ctrl.A_enable),
        .signal(move_ctrl.A_signal),
        .speed(speed)
    );

    // 角度计算
    angle_caculator #(.INIT_ANGLE(PLAYER_INIT_ANGLE))u_angle_cacluator(
        .game_clk(player_game_clk),
        .rst(rst),
        .enable(move_ctrl.W_enable),
        .signal(move_ctrl.W_signal),
        .angle(angle)
    );

    /*************   内置AI  ********************/
    wire [7:0] ai_left_angle;
    wire [7:0] ai_right_angle;
    wire [7:0] ai_action_cmd;
    //[TODO]
    /*************  分层状态机   ******************/
    wire [7:0] input_left_angle;
    wire [7:0] input_right_angle;
    wire [7:0] input_action_cmd;
    assign input_left_angle = selected ? cmd_left_angle : ai_left_angle;
    assign input_right_angle = selected ? cmd_right_angle : ai_right_angle;
    assign input_action_cmd = selected ? cmd_action_cmd : ai_action_cmd;
    HFSM U_HFSM(
        .HFSM_game_clk(player_game_clk),
        .rst(rst),
        .hold(hold),
        .self_info(self_info),
        .ball_info(ball_info),
        .left_angle(input_left_angle),
        .right_angle(input_right_angle),
        .action_cmd(input_action_cmd),
        .move_ctrl(move_ctrl),
        .anim_stat(anim_stat)
    );
    
    /*************  渲染预处理器   ****************/


endmodule