// 分层状态机  (重中之重)

import type_declare::*;
module HFSM_copy
// SELECTED = 1表示该球员是初始被操控的球员（上层保证只给一个实例赋这个值）
#(parameter PLAYER_MAX_V = 4, INIT_STAT = 0)
(
    input HFSM_game_clk,
    input rst,

    input hold, //该人物是否持球，由上层controller.sv决定
    input selected,     // 当前球员是否被选中
    //当前状态
    input PlayerInfo self_info,
    input BallInfo ball_info,
    //其它球员的信息
    input PlayerInfo teammate_info1,
    input PlayerInfo rival_info1,
    //外部命令，这里可以由cmd生成，也可以由AI生成
    input [7:0] left_angle,
    input [7:0] right_angle,
    input [7:0] action_cmd,
    //操控信号，在同队不同球员之间传递
    
    output [2:0] select_index,      //切换球员的新编号
    
    //设置，控制效果
    output MoveControl mv_ctrl,

    //[TODO]在发球的时候，或者持球的时候，设置相应的参数，同时将tackle/shoot信号进行相应的变化
    output reg player_tackle_signal,
    output reg player_shoot_signal,
    output ConstrainedInit const_ball_parameter,
    output FreeInit free_ball_parameter,           
    
    output reg action_message,        // 比如进行抢断时，是否判定成功
    
    output reg [2:0] pre_switch_index,      // 预选编号，用于将其脚下的圆圈替换成特殊颜色
    
);
    /*********   Move_FSM  ************/
    wire MoveControl basic_ctrl;
    Move_FSM u_Move_FSM(
        .Move_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .sprint(action_cmd[0]),     // L1键为冲刺
        .left_angle(left_angle),
        .self_info(self_info),
        .basic_ctrl(basic_ctrl)
    );


    /**********   Tackle_FSM   *************/
    reg tackle_start;
    reg tackle_done;
    reg [1:0] tackle_message;
    //用于打断动作
    reg cancel;
    MoveControl tackle_ctrl;
    //向上层传递的信息，主要用于汇报动作是否成功
    reg [1:0] message;    // 1:成功， 2：失败， 0：未定义
    Tackle_FSM u_Tackle_FSM(
        .Tackle_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .tackle_start(tackle_start),
        .done(tackle_done),
        //输入信息
        .self_info(self_info),
        .ball_info(ball_info),
        //控制
        .tackle_ctrl(tackle_ctrl),
        //向上层传递的信息，主要用于汇报动作是否成功
        .message(tackle_message)    // 1:成功， 2：失败， 0：未定义
    );

    /*********  GroundShoot_FSM  ***********/

    // 设置对球的约束，一直存在，但只有hold关系正确才会采用
    assign const_ball_parameter.master_x = self_info.x;
    assign const_ball_parameter.master_y = self_info.y;
    assign const_ball_parameter.master_height = 0;
    assign const_ball_parameter.master_radius = 10;
    assign const_ball_parameter.master_angle = self_info.angle;
    reg gnd_shoot_start;
    reg gnd_shoot_done;
    reg [1:0]gnd_shoot_message;
    reg [7:0]gnd_shoot_speed;
    GroundShoot_FSM(
        .GroundShoot_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .gnd_shoot_cmd(),
        .GroundShoot_FSM_done(gnd_shoot_done),
        .gnd_shoot_speed(gnd_shoot_speed),
        .GroundShoot_FSM_message(gnd_shoot_message)
    );

    /*********  Switch_FSM  ************/
    reg switch_start;
    reg switch_done;
    reg [3:0] switch_message;


    
    /************  HFSM  *************/
    reg [5:0] player_stat;  //真正用于逻辑的状态寄存器
    localparam IDLE = 8'd0, TURN = 8'd1, TACKLE = 8'd2, GROUND_SHOOT = 8'd3, SWITCH = 8'd4;


    always @(posedge HFSM_game_clk) begin
        if(rst) begin
            player_stat <= IDLE;   //外界可以控制
        end else begin
            case(player_stat)
                IDLE:
                    
                    
                TACKLE:
                    if(FSM_counter == 3'd0)begin
                        tackle_start <= 1'b1;    
                        FSM_counter <= FSM_counter + 3'd1;
                    end else if(FSM_counter == 3'd1)begin
                        tackle_start <= 1'b0;   //将tacle_start的拉高一个周期，标志着正式进入tackle状态机
                        A_enable <= tackle_AE;
                        A_signal <= tackle_AS;
                        W_enable <= tackle_WE;
                        W_signal <= tackle_WS;
                        
                        if(tackle_done)begin
                            if(tackle_message == 2'd1)begin
                                //成功，将player_tackle_signal拉高一个周期
                                player_tackle_signal <= 1'b1;
                            end
                            FSM_counter <= FSM_counter + 3'd1;
                        end
                    end else begin
                        player_tackle_signal <= 1'b0;
                        FSM_counter <= 3'd0;     //计数器清零，为下一次准备
                        player_stat <= IDLE;        //抢断状态结束
                    end

                GROUND_SHOOT:
                    if(FSM_counter == 3'd0)begin
                        gnd_shoot_start <= 1'b1;
                        FSM_counter <= FSM_counter + 3'd1;
                    end else if(FSM_counter == 3'd1)begin
                        gnd_shoot_start <= 1'b0;
                        if(gnd_shoot_done)begin
                            if(gnd_shoot_message == 2'd1)begin  //成功
                                free_ball_parameter.init_speed <= gnd_shoot_speed;
                                free_ball_parameter.init_angle <= player_angle;
                                free_ball_parameter.init_vertical_speed <= 8'd0;
                                free_ball_parameter.init_vertical_signal <= 1'b0;
                                player_shoot_signal <= 1'b1;    //拉高
                            end
                            FSM_counter <= FSM_counter + 3'd1;
                        end
                    end else begin
                        player_shoot_signal <= 1'b0;
                        FSM_counter <= 3'd0;
                        player_stat <= IDLE;
                    end
                SWITCH:
                    if(FSM_counter == 3'd0)begin
                        switch_start <= 1'b1; 
                        FSM_counter <= FSM_counter + 3'd1;
                    end else if(FSM_counter == 3'd1)begin
                        switch_start <= 1'b0;   //将tacle_start的拉高一个周期，标志着正式进入tackle状态机
                        if(switch_done)begin
                            self_selected <= 1'b0;      //自己不再被选中
                            //[TODO]如果后续拓展了运动员，这里的范围也需要修改
                            if(switch_message == 4'd1)begin
                                select_1 <= 1'b1;
                            end else if(switch_message == 4'd2)begin
                                select_2 <= 1'b1;
                            end else if(switch_message == 4'd3)begin
                                select_3 <= 1'b1;
                            end else if(switch_message == 4'd4)begin
                                select_4 <= 1'b1;
                            end 
                            FSM_counter <= FSM_counter + 3'd1;
                        end
                    end else begin
                        select_1 <= 1'b0;
                        select_2 <= 1'b0;
                        select_3 <= 1'b0;
                        select_4 <= 1'b0;
                        FSM_counter <= 3'd0;     //计数器清零，为下一次准备
                        player_stat <= IDLE;        //切换状态结束
                    end
                    
                default: player_stat <= IDLE;
            endcase
        end
    end

endmodule