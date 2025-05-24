// 分层状态机  (重中之重)

import type_declare::*;
module HFSM
// SELECTED = 1表示该球员是初始被操控的球员（上层保证只给一个实例赋这个值）
#(parameter PLAYER_MAX_V = 4, INIT_STAT = 0, SELECTED = 0)
(
    input HFSM_game_clk,
    input rst,

    input hold, //该人物是否持球，由上层controller.sv决定
    
    //当前状态
    input [15:0] player_x,
    input [15:0] player_y,
    input [7:0] player_speed,
    input [7:0] player_angle,
    input [15:0] football_x,
    input [15:0] football_y,
    input [15:0] football_z,
    //命令
    input [7:0] left_angle,
    input [7:0] right_angle,
    input [7:0] action_cmd,
    //操控信号，在同队不同球员之间传递
    input selected,     //当该信号拉高一个周期时，该球员被选中
    output reg select_1,
    output reg select_2,
    output reg select_3,
    output reg select_4,
    //其它球员的信息
    PlayerInfo playerInfo_1,
    //设置，控制效果
    output reg A_enable,
    output reg A_signal,
    output reg W_enable,
    output reg W_signal,
    output reg anmi_stat,

    //[TODO]在发球的时候，或者持球的时候，设置相应的参数，同时将tackle/shoot信号进行相应的变化
    output reg player_tackle_signal,
    output reg player_shoot_signal,
    output ConstrainedInit const_ball_parameter,
    output FreeInit free_ball_parameter,           
    
    output reg action_message        // 比如进行抢断时，是否判定成功
    

);
`include "trangleval.sv"
`include "angle.sv"
    reg [5:0] player_stat;  //真正用于逻辑的状态寄存器
    reg [7:0] turn_parameter;   //在一个转向turn中，用于标记是否有新的转向
    reg [7:0] current_speed_max;    //当前的速度阈值，如果超过这个速度，需要先减速才能完成下一步的操作
    wire [7:0] rel_angle = rel_angle_val(player_angle, left_angle);
    wire [1:0] rel_pos = rel_angle_pos(player_angle, left_angle);
    reg FSM_restart;        //自动机重置标记，当设置为1的时候，再从起始状态执行自动机
    localparam IDLE = 8'd0, TURN = 8'd1, TACKLE = 8'd2, GROUND_SHOOT = 8'd3, SWITCH = 8'd4;

    reg [2:0] FSM_counter;  //用于在单一状态中计数（一定要在每个状态的最后清零）
    reg self_selected;           //当前球员是否被选中

    /**********   Tackle_FSM   *************/
    reg tackle_start;
    reg tackle_done;
    reg [1:0] tackle_message;
    //用于打断动作
    reg cancel;
    reg tackle_AE;
    reg tackle_AS;
    reg tackle_WE;
    reg tackle_WS;
    //向上层传递的信息，主要用于汇报动作是否成功
    reg [1:0] message;    // 1:成功， 2：失败， 0：未定义
    Tackle_FSM u_Tackle_FSM(
        .Tackle_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .tackle_start(tackle_start),
        .done(tackle_done),
        //输入信息
        .player_x(player_x),
        .player_y(player_y),
        .player_angle(player_angle),
        .player_speed(player_speed),
        .football_x(football_x),
        .football_y(football_y),
        .football_z(football_z),
        //控制
        .A_enable(tackle_AE),
        .A_signal(tackle_AS),
        .W_enable(tackle_WE),
        .W_signal(tackle_WS),
        //向上层传递的信息，主要用于汇报动作是否成功
        .message(tackle_message)    // 1:成功， 2：失败， 0：未定义
    );

    /*********  GroundShoot_FSM  ***********/
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

    always @(posedge HFSM_game_clk) begin
        if(rst) begin
            turn_parameter <= 8'hFF;
            //tackle初始化
            FSM_counter <= 3'd0;
            tackle_start <= 1'b0;
            gnd_shoot_start <= 1'b0;
            tackle_message <= 2'd0;
            gnd_shoot_message <= 2'd0;
            player_stat <= INIT_STAT;   //外界可以控制
            self_selected <= SELECTED;
        end else begin
            // 如果select信号拉高，表明该球员被选中
            if(selected)begin
                self_selected <= 1'b1;  //自身被选中
            end
            // 设置对球的约束，一直存在，但只有hold关系正确才会采用
            const_ball_parameter.master_x <= player_x;
            const_ball_parameter.master_y <= player_y;
            const_ball_parameter.master_height <= 0;
            const_ball_parameter.master_radius <= 10;
            const_ball_parameter.master_angle <= player_angle;
            case(player_stat)
                IDLE:
                    // 在这个状态下，如果速度不满，进行加速(弥补了转向后的减速惩罚)
                    if(speed < PLAYER_MAX_V) begin
                        A_enable <= 1'b1;   // 保持加速度（加速度器中会进行约束）
                        A_signal <= 1'b0;
                        W_enable <= 1'b0;
                    end else begin
                        A_enable <= 1'b0;
                        W_enable <= 1'b0;
                    end
                    
                    if(self_selected)begin
                        //根据cmd信号进行状态转移
                        if(action_cmd[0])begin
                            //L1门将
                            ;
                        end else if(action_cmd[1])begin
                            //L2奔跑
                            ;
                        end else if(action_cmd[2])begin
                            //R1保留
                            ;
                        end else if(action_cmd[3])begin
                            //R2切换
                            player_stat <= SWITCH;
                        end else if(action_cmd[4])begin
                            //A
                            if(hold)begin
                                player_stat <= GROUND_SHOOT;
                            end else begin
                                player_stat <= TACKLE;
                            end
                        end else if(action_cmd[5])begin
                            //B
                            ;
                        end else if(action_cmd[6])begin
                            //X
                            ;
                        end else if(action_cmd[7])begin 
                            //Y  
                            ;
                        end
                    end else begin
                        //根据AI模块进行状态转移
                        ;
                    end
                    
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