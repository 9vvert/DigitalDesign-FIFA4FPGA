// 足球运动员模块
import type_declare::PlayerInfo, type_declare::MoveControl;
import field_package::*;
module player
#(parameter PLAYER_INIT_X = 0, PLAYER_INIT_Y = 0, PLAYER_INIT_V = 0, PLAYER_INIT_ANGLE = 0, PLAYER_INDEX=1,
    KEEPER = 0, XMIN = 0, XMAX = 300, YMIN = 0, YMAX = 300
)
(
    input player_game_clk,           //和游戏时钟频率相同
    input rst, 
    input enable,           //是否开始游戏
    //ai输入的信号
    input [7:0] ai_left_angle,
    input [7:0] ai_right_angle,
    input [7:0] ai_action_cmd,
    //cmd输入的信号，但是不一定有效，需要通过selected来决定是否使用
    input [7:0] cmd_left_angle,
    input [7:0] cmd_right_angle,
    input [7:0] cmd_action_cmd,
    //输出，用于 1.渲染  2.模块之间交互 3.AI参数
    input hold,    // 当输出hold信号时，持续2个周期，外部捕捉到这个信号，交给仲裁器
    input selected,                 // 自己是否被选中，如果是的话，一直为高。
    input targeted,
    // input pre_switch_target,        // 自己是否为预切换的对象

    //输入其它对象的信息
    input BallInfo ball_info,
    input delay,    
    //输出自己的信息以及控制信号
    output tackle_signal,
    output shoot_signal,
    output switch_signal,       //[TODO]维护一个“预备切换对象”，每次读取到该信号的时候，切换到那个球员
    output PlayerInfo self_info,
    output ConstrainedInit out_const,
    output FreeInit out_free,
    output [2:0]shoot_level
);
    reg [11:0] pos_x;
    reg [11:0] pos_y;
    reg [7:0] speed;
    reg [7:0] angle;
    wire [3:0] anim_stat;
    MoveControl move_ctrl;
 
    always@(posedge player_game_clk)begin
        self_info.target <= targeted;
        self_info.selected <= selected;
        self_info.index <= PLAYER_INDEX;
        self_info.anim_stat <= anim_stat; 
        self_info.x <= pos_x;
        self_info.y <= pos_y;
        self_info.speed <= speed;
        self_info.angle <= angle;
    end 

    /******************* 物理引擎  *********************/
    // 坐标计算
    position_caculator #(.INIT_X(PLAYER_INIT_X), .INIT_Y(PLAYER_INIT_Y),
        .X_MIN(XMIN), .X_MAX(XMAX), .Y_MIN(YMIN), .Y_MAX(YMAX)
    )u_position_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .in_angle(angle),
        .in_speed(speed),
        .out_x(pos_x),
        .out_y(pos_y),
        .set_pos_enable(0),
        .set_x_val(PLAYER_INIT_X),
        .set_y_val(PLAYER_INIT_Y)
    );

    // 速度计算
    speed_caculator #(.V_INIT(PLAYER_INIT_V))u_speed_caculator(
        .game_clk(player_game_clk),
        .rst(rst),
        .enable(move_ctrl.A_enable),
        .signal(move_ctrl.A_signal),
        .speed(speed),
        .set_speed_enable(0),
        .set_speed_val(PLAYER_INIT_V)

    );

    // 角度计算
    angle_caculator #(.INIT_ANGLE(PLAYER_INIT_ANGLE), .KEEPER(KEEPER))u_angle_cacluator(
        .game_clk(player_game_clk),
        .rst(rst),
        .delay(delay),      // 非持球的人机，让其转向变慢，来抵消一部分影响
        .enable(move_ctrl.W_enable),
        .signal(move_ctrl.W_signal),
        .angle(angle),
        .set_angle_enable(0),
        .set_angle_val(0)
    );

    //[TODO]
    /*************  分层状态机   ******************/
    wire [7:0] input_left_angle;
    wire [7:0] input_right_angle;
    wire [7:0] input_action_cmd;
    assign input_left_angle = enable ? (selected ? cmd_left_angle : 
                                 ai_left_angle ): 'hFF;
    assign input_right_angle = enable ? (selected ? cmd_right_angle : 
                                 ai_right_angle ) : 'hFF;
    assign input_action_cmd = enable ? (selected ? cmd_action_cmd : 
                                 ai_action_cmd ) : 'h00;
    HFSM U_HFSM(
        .HFSM_game_clk(player_game_clk),
        .rst(rst),
        .hold(hold),
        .selected(selected),
        .self_info(self_info),
        .ball_info(ball_info),
        .left_angle(input_left_angle),
        .right_angle(input_right_angle),
        .action_cmd(input_action_cmd),
        .move_ctrl(move_ctrl),
        .shoot_level(shoot_level),      // 蓄力等级， 0代表不渲染，其余分为1-5
        .anim_stat(anim_stat),
        //
        .player_tackle_signal(tackle_signal),
        .player_shoot_signal(shoot_signal),
        .player_switch_signal(switch_signal),
        //控球参数
        .const_ball_parameter(out_const),
        .free_ball_parameter(out_free)

    );
    
    /*************  渲染预处理器   ****************/


endmodule