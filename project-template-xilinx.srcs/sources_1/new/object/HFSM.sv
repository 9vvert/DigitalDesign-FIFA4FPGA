// 分层状态机  (重中之重)

import type_declare::*;
module HFSM
// SELECTED = 1表示该球员是初始被操控的球员（上层保证只给一个实例赋这个值）
#(parameter PLAYER_MAX_V = 4, INIT_STAT = 0)
(
    input HFSM_game_clk,
    input rst,
    output reg [31:0]debug_number,
    input hold, //该人物是否持球，由上层controller.sv决定
    //当前状态
    input PlayerInfo self_info,
    input BallInfo ball_info,
    //其它球员的信息
    // input PlayerInfo teammate_info1,
    // input PlayerInfo rival_info1,
    //外部命令，这里可以由cmd生成，也可以由AI生成
    input [7:0] left_angle,
    input [7:0] right_angle,
    input [7:0] action_cmd,
    //操控信号，在同队不同球员之间传递
    
    output [2:0] select_index,      //切换球员的新编号
    
    //设置，控制效果
    output MoveControl move_ctrl,

    //[TODO]在发球的时候，或者持球的时候，设置相应的参数，同时将tackle/shoot信号进行相应的变化
    output reg player_tackle_signal,
    output reg player_shoot_signal,
    output ConstrainedInit const_ball_parameter,
    output FreeInit free_ball_parameter,           
    
    output reg action_message,        // 比如进行抢断时，是否判定成功
    
    output reg [2:0] pre_switch_index,      // 预选编号，用于将其脚下的圆圈替换成特殊颜色
    output reg [3:0] anim_stat
);
    


    /*********   Move_FSM  ************/
    wire MoveControl basic_ctrl;
    wire [3:0] move_anim_stat;
    assign anim_stat = move_anim_stat;
    Move_FSM u_Move_FSM(
        .debug_number(debug_number),
        .Move_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .sprint(action_cmd[0]),     // L1键为冲刺
        .left_angle(left_angle),
        .self_info(self_info),
        .basic_ctrl(basic_ctrl),
        .move_anim_stat(move_anim_stat)
    );


    // /**********   Tackle_FSM   *************/
    // reg tackle_start;
    // reg tackle_done;
    // reg [1:0] tackle_message;
    // //用于打断动作
    // reg cancel;
    // MoveControl tackle_ctrl;
    // //向上层传递的信息，主要用于汇报动作是否成功
    // reg [1:0] message;    // 1:成功， 2：失败， 0：未定义
    // Tackle_FSM u_Tackle_FSM(
    //     .Tackle_FSM_game_clk(HFSM_game_clk),
    //     .rst(rst),
    //     .tackle_start(tackle_start),
    //     .done(tackle_done),
    //     //输入信息
    //     .self_info(self_info),
    //     .ball_info(ball_info),
    //     //控制
    //     .tackle_ctrl(tackle_ctrl),
    //     //向上层传递的信息，主要用于汇报动作是否成功
    //     .message(tackle_message)    // 1:成功， 2：失败， 0：未定义
    // );

    /*********  GroundShoot_FSM  ***********/

    // // 设置对球的约束，一直存在，但只有hold关系正确才会采用
    // assign const_ball_parameter.master_x = self_info.x;
    // assign const_ball_parameter.master_y = self_info.y;
    // assign const_ball_parameter.master_height = 0;
    // assign const_ball_parameter.master_radius = 10;
    // assign const_ball_parameter.master_angle = self_info.angle;
    // reg gnd_shoot_start;
    // reg gnd_shoot_done;
    // reg [1:0]gnd_shoot_message;
    // reg [7:0]gnd_shoot_speed;
    // GroundShoot_FSM(
    //     .GroundShoot_FSM_game_clk(HFSM_game_clk),
    //     .rst(rst),
    //     .hold(hold),
    //     .gnd_shoot_cmd(),
    //     .GroundShoot_FSM_done(gnd_shoot_done),
    //     .gnd_shoot_speed(gnd_shoot_speed),
    //     .GroundShoot_FSM_message(gnd_shoot_message)
    // );

    /*********  Switch_FSM  ************/
    reg switch_start;
    reg switch_done;
    reg [3:0] switch_message;


    
    /************  HFSM  *************/
    reg [5:0] player_stat;  //真正用于逻辑的状态寄存器
    localparam IDLE = 8'd0, TACKLE = 8'd2, GROUND_SHOOT = 8'd3, SWITCH = 8'd4;

    assign move_ctrl = basic_ctrl;

    always @(posedge HFSM_game_clk) begin
        if(rst) begin
            player_stat <= IDLE;   //外界可以控制
        end else begin
            case(player_stat)
                IDLE: begin
                    player_stat <= IDLE;
                end 
                default:
                    player_stat <= IDLE;
                    
        // 动画机切换 2-1-2-3

            endcase
        end
    end

endmodule