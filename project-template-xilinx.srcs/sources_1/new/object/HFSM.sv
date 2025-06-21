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
    input selected,
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
    
    
    

    //[TODO]在发球的时候，或者持球的时候，设置相应的参数，同时将tackle/shoot信号进行相应的变化
    output player_tackle_signal,
    output player_shoot_signal,
    output player_switch_signal,
    output ConstrainedInit const_ball_parameter,
    output FreeInit free_ball_parameter,           
    //设置，控制效果
    output MoveControl move_ctrl,
    output [2:0] shoot_level,       //用于外部渲染
    output reg [3:0] anim_stat
);
    import TrianglevalLib::*;
    /************  HFSM变量  *************/
    reg [5:0] player_stat;  //真正用于逻辑的状态寄存器
    localparam IDLE=0, TACKLE=1, LOB_SHOOT=2, GROUND_SHOOT=3, SWITCH_PLAYER=4;
    reg [5:0]delay_counter;


    /********** follow ***********/
    wire follow_enable;          // 是否启用追随机，如果启用，则会用follow_left_angle覆盖外界的left_angle
    reg [11:0] aim_x;
    reg [11:0] aim_y;
    wire [7:0] follow_left_angle;
    follow u_follow(
        .game_clk(HFSM_game_clk),
        .rst(rst),
        .enable(follow_enable),       // 只在enable = 1时工作，而且会实时读取obj_angle, obj_speed, aim_speed的数值
        .self_info(self_info),
        .aim_x(ball_info.x),
        .aim_y(ball_info.y),
        .follow_left_angle(follow_left_angle)
    );


    /*********   Move_FSM  ************/
    wire MoveControl basic_ctrl;
    wire [3:0] move_anim_stat;
    wire [7:0] move_left_angle;
    wire move_sprint;
    assign anim_stat = move_anim_stat;
    assign move_ctrl = basic_ctrl;
    Move_FSM u_Move_FSM(
        .debug_number(debug_number),
        .Move_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        // 控制
        .sprint(move_sprint),     // L1键为冲刺
        .left_angle(move_left_angle),
        .self_info(self_info),
        // 输出
        .basic_ctrl(basic_ctrl),
        .move_anim_stat(move_anim_stat)
    );


    /**********   Tackle_FSM   *************/
    //用于打断动作
    wire tackle_use_follow;
    wire tackle_done;
    wire tackle_enable;
    wire tackle_signal;
    reg [11:0] loss_counter;        // 当丢球后，需要有一定的冷却时间，期间不能进行tackle
    assign tackle_enable = (player_stat == TACKLE ? action_cmd[4] : 0);
    Tackle_FSM u_Tackle_FSM(
        .Tackle_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .tackle_enable(tackle_enable),      //当且仅当抢断按键按下时
        //输入信息
        .self_info(self_info),
        .ball_info(ball_info),
        //控制
        .tackle_use_follow(tackle_use_follow),
        .tackle_signal(tackle_signal),
        .tackle_done(tackle_done)
    );


    reg [11:0] last_x;
    reg [11:0] last_y;
    reg [7:0] last_angle;
    reg [7:0] last_speed;
    //带球转动可能出现黑屏，初步猜测是组合逻辑延时，带来的信号不稳定性。延时一个周期计算，让其稳定后直接传入const_init
    always@(posedge HFSM_game_clk)begin
        last_x <= self_info.x;
        last_y <= self_info.y;
        last_angle <= self_info.angle;
        last_speed <= self_info.speed;
        const_ball_parameter.master_speed <= last_speed;
        const_ball_parameter.master_height <= 0;

        if(last_angle < 8'd18) begin
            const_ball_parameter.master_x <= last_x + sin(last_angle);
            const_ball_parameter.master_y <= last_y + cos(last_angle);
        end else if(last_angle < 8'd36) begin
            const_ball_parameter.master_x <= last_x + cos(last_angle - 8'd18);
            const_ball_parameter.master_y <= last_y - sin(last_angle - 8'd18);
        end else if(last_angle < 8'd54) begin
            const_ball_parameter.master_x <= last_x - sin(last_angle - 8'd36);
            const_ball_parameter.master_y <= last_y - cos(last_angle - 8'd36);
        end else if(last_angle < 8'd72)begin      // 防止出现锁存器，需要保证传入的angle不是 'hFF
            const_ball_parameter.master_x <= last_x - cos(last_angle - 8'd54);
            const_ball_parameter.master_y <= last_y + sin(last_angle - 8'd54);
        end else begin
            const_ball_parameter.master_x <= last_x;
            const_ball_parameter.master_y <= last_y;
        end
    end

    /************ GroundShoot_FSM  *******************/
    wire [2:0]gnd_shoot_level;
    wire gnd_shoot_enable;
    FreeInit gnd_shoot_free_init;
    wire gnd_shoot_signal;
    wire gnd_shoot_done;
    assign gnd_shoot_enable = (player_stat == GROUND_SHOOT ? action_cmd[5] : 0);        
    // 如果不处于GROUND_SHOOT状态，按下是没有反应的，所以不必担心自动机非法启动
    GroundShoot_FSM u_GroundShoot_FSM(
        .GroundShoot_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .shoot_enable(gnd_shoot_enable),
        .self_info(self_info),
        .free_init(gnd_shoot_free_init),
        .shoot_signal(gnd_shoot_signal),
        .shoot_level(gnd_shoot_level),
        .shoot_done(gnd_shoot_done)
    );

    /************ LobShoot_FSM  *******************/
    wire [2:0]lob_shoot_level;
    wire lob_shoot_enable;
    FreeInit lob_shoot_free_init;
    wire lob_shoot_signal;
    wire lob_shoot_done;
    assign lob_shoot_enable = (player_stat == LOB_SHOOT ? action_cmd[7] : 0);        
    // 如果不处于GROUND_SHOOT状态，按下是没有反应的，所以不必担心自动机非法启动
    LobShoot_FSM u_LobShoot_FSM(
        .LobShoot_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .hold(hold),
        .shoot_enable(lob_shoot_enable),
        .self_info(self_info),
        .free_init(lob_shoot_free_init),
        .shoot_signal(lob_shoot_signal),
        .shoot_level(lob_shoot_level),
        .shoot_done(lob_shoot_done)
    );

    /************  SwitchPlayer_FSM  ******************/
    wire switch_enable;
    wire switch_signal;
    wire switch_done;
    reg [9:0] switch_tol_counter;
    assign switch_enable = (player_stat == SWITCH_PLAYER ? 1 : 0);
    SwichPlayer_FSM u_SwitchPlayer_FSM(
        .SwichPlayer_FSM_game_clk(HFSM_game_clk),
        .rst(rst),
        .selected(selected),
        .switch_enable(switch_enable),        //切换使能
        .switch_signal(switch_signal),
        .switch_done(switch_done)
    );

    
    /**********************  总信号仲裁  *****************/

    assign move_sprint = action_cmd[0];
    assign move_left_angle = (follow_enable ? follow_left_angle : left_angle);

    assign follow_enable = (player_stat == TACKLE ? tackle_use_follow : 0);

    assign player_tackle_signal = (player_stat == TACKLE ? tackle_signal : 0);
    assign player_shoot_signal =  (player_stat == GROUND_SHOOT ? gnd_shoot_signal : lob_shoot_signal);
    assign free_ball_parameter = (player_stat == GROUND_SHOOT ? gnd_shoot_free_init : lob_shoot_free_init);
    assign shoot_level = (player_stat == GROUND_SHOOT ? gnd_shoot_level :
                        player_stat == LOB_SHOOT ? lob_shoot_level  : 0);  
    assign player_switch_signal = (player_stat == SWITCH_PLAYER ? switch_signal : 0);
    

    reg last_switch;        //用于捕捉上升沿
    reg last_hold;
    always @(posedge HFSM_game_clk) begin
        if(rst) begin
            player_stat <= IDLE;   //外界可以控制
            last_switch <= 0;
            last_hold <= 0;
            switch_tol_counter <= 0;
            loss_counter <= 0;
        end else begin
            last_switch <= action_cmd[1];
            last_hold <= hold;
            if(switch_tol_counter > 0) begin
                switch_tol_counter <= switch_tol_counter - 1;
            end
            if(loss_counter > 0)begin
                loss_counter <= loss_counter - 1;
            end 
            if( last_hold & ~hold)begin
                //丢球，可能自己投出或者被抢断。进入2s的无法抢断状态
                loss_counter <= 2000;
            end
            case(player_stat)
                IDLE: begin
                    
                    if(hold)begin           // 持球者
                        // 持球者不能进行切换
                        if(action_cmd[5])begin
                            player_stat <= GROUND_SHOOT;
                        end else if(action_cmd[7])begin
                            player_stat <= LOB_SHOOT;
                        end 
                    end else begin          // 非持球者
                        if(~last_switch & action_cmd[1]  && switch_tol_counter == 0)begin
                            switch_tol_counter <= 800;
                            player_stat <= SWITCH_PLAYER;
                        end else if(action_cmd[4] && loss_counter == 0)begin  // A，抢断
                            player_stat <= TACKLE;
                        end 
                    end
                end 
                TACKLE: begin
                    if(tackle_done)begin
                        player_stat <= IDLE;
                    end
                end
                GROUND_SHOOT:begin
                    if(gnd_shoot_done)begin
                        player_stat <= IDLE;
                    end
                end
                LOB_SHOOT:begin
                    if(lob_shoot_done)begin
                        player_stat <= IDLE;
                    end
                end
                SWITCH_PLAYER:begin
                    if(switch_done)begin
                        player_stat <= IDLE;
                    end
                end
                default:
                    player_stat <= IDLE;
                    
        // 动画机切换 2-1-2-3

            endcase
        end
    end

endmodule