import type_declare::PlayerInfo, type_declare::BallInfo;
import field_package::*;
module game(
    input game_clk,     // 游戏帧
    input ps2_clk,
    input rst,
    output [15:0]debug_number,
    // ps2接口
    output wire pmod1_io1,
    input wire pmod1_io2,
    output wire pmod1_io3,
    output reg pmod1_io4,
    output wire pmod2_io1,
    input wire pmod2_io2,
    output wire pmod2_io3,
    output reg pmod2_io4,
    //game需要向外输出的是： bg, 渲染组件
    //不需要通讯协议，持续输出，等显存准备好了就会渲染
    output PlayerInfo player_info[9:0],
    output BallInfo ball_info,
    output reg [3:0]points_1,
    output reg [3:0]points_2,
    output [2:0] shoot_level[9:0],
    output [3:0] player_hold_index,
    output reg [5:0] game_bg      // 当前的场景
);
    import LineLib::*;
    import AngleLib::*;
    import TrianglevalLib::*;
    /******************  变量定义       *******************/

    //cmd解码器输出的控制信号
    
    //
    ConstrainedInit const_init[9:0];
    ConstrainedInit football_const_init;
    FreeInit football_free_init;
    FreeInit free_init [9:0];
    
    //总控制器输入
    wire [9:0] tackle_signal;
    wire [9:0] shoot_signal;
    wire [9:0]switch_signal;      // 正常情况下，应该为0；真正有效的信号范围是1-10
    //总控制器输出
    wire football_being_held;
    wire [9:0] player_hold;
    wire [9:0] player_selected;
    logic [9:0] player_targeted;
    wire [3:0] player_selected_index1;        // 第一组选择的index
    wire [3:0] player_selected_index2;        // 第二组选择的index
    // ai模拟指令
    wire [7:0] ai_left_angle[9:0];
    wire [7:0] ai_right_angle[9:0];
    wire [7:0] ai_action_cmd[9:0];

    /***************** AI 控制器  *****************/
    ai_controller u_ai_controller(
        .ai_game_clk(game_clk),
        .rst(rst),
        .hold_index(player_hold_index),
        .selected_index1(player_selected_index1),
        .selected_index2(player_selected_index2),
        .player_info(player_info),
        .ball_info(ball_info),
        .ai_left_angle(ai_left_angle),
        .ai_right_angle(ai_right_angle),
        .ai_action_cmd(ai_action_cmd)
    );


    /******************  手柄控制器 1   *******************/
    reg [7:0] cmd_left_angle1;
    reg [7:0] cmd_right_angle1;
    reg [7:0] cmd_action_cmd1;
    cmd_decoder u_cmd_decoder1(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod1_io1),
        .pmod_io2(pmod1_io2),
        .pmod_io3(pmod1_io3),
        .pmod_io4(pmod1_io4),
        .left_angle(cmd_left_angle1), 
        .right_angle(cmd_right_angle1),
        .action_cmd2(cmd_action_cmd1)        //已经完成消抖
    );


    /******************  手柄控制器 2   *******************/
    reg [7:0] cmd_left_angle2;
    reg [7:0] cmd_right_angle2;
    reg [7:0] cmd_action_cmd2;
    cmd_decoder u_cmd_decoder2(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod2_io1),
        .pmod_io2(pmod2_io2),
        .pmod_io3(pmod2_io3),
        .pmod_io4(pmod2_io4),
        .left_angle(cmd_left_angle2), 
        .right_angle(cmd_right_angle2),
        .action_cmd2(cmd_action_cmd2)        //已经完成消抖
    );

    /*************** 游戏总体控制  *****************/
    reg pause;
    reg [1:0] last_pos_flag;
    wire [1:0] pos_flag;
    always @(posedge game_clk) begin
        if(rst)begin
            pause <= 1;
            points_1 <= 0;
            points_2 <= 0;
            last_pos_flag <= 0;
        end else begin
            last_pos_flag <= pos_flag;
            if(pause)begin
                if(cmd_action_cmd1[6] || cmd_action_cmd2[6])begin
                    pause <= 0;             // 任意一方按下X键开始
                end 
            end else begin
                if(last_pos_flag == 0 && (pos_flag == 1))begin
                    points_2 <= points_2 + 1;
                end else if(last_pos_flag == 0 && (pos_flag == 2))begin
                    points_1 <= points_1 + 1;
                end
            end
        end
    end


    /***************** 球员 *******************/
    
    player #(.PLAYER_INIT_X(PLAYER0_X), .PLAYER_INIT_Y(PLAYER0_Y),
    .PLAYER_INIT_ANGLE(18), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_0(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[0]),
        .ai_right_angle(ai_right_angle[0]),
        .ai_action_cmd(ai_action_cmd[0]),
        .cmd_left_angle(cmd_left_angle1),
        .cmd_right_angle(cmd_right_angle1),
        .cmd_action_cmd(cmd_action_cmd1),
        //
        .delay(~player_selected[0]),    //如果是人机，才延时
        .enable(~pause),
        .hold(player_hold[0]),
        .selected(player_selected[0]),
        .targeted(player_targeted[0]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[0]),
        .out_const(const_init[0]),
        .out_free(free_init[0]),
        .shoot_level(shoot_level[0]),
        .tackle_signal(tackle_signal[0]),
        .shoot_signal(shoot_signal[0]),
        .switch_signal(switch_signal[0])
    );

    player #(.PLAYER_INIT_X(PLAYER1_X), .PLAYER_INIT_Y(PLAYER1_Y),
    .PLAYER_INIT_ANGLE(18), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_1(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[1]),
        .ai_right_angle(ai_right_angle[1]),
        .ai_action_cmd(ai_action_cmd[1]),
        .cmd_left_angle(cmd_left_angle1),
        .cmd_right_angle(cmd_right_angle1),
        .cmd_action_cmd(cmd_action_cmd1),
        //
        .delay(~player_selected[1]),
        .enable(~pause),
        .hold(player_hold[1]),
        .selected(player_selected[1]),
        .targeted(player_targeted[1]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[1]),
        .out_const(const_init[1]),
        .out_free(free_init[1]),
        .shoot_level(shoot_level[1]),
        .tackle_signal(tackle_signal[1]),
        .shoot_signal(shoot_signal[1]),
        .switch_signal(switch_signal[1])
    );

    player #(.PLAYER_INIT_X(PLAYER2_X), .PLAYER_INIT_Y(PLAYER2_Y),
    .PLAYER_INIT_ANGLE(18), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_2(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[2]),
        .ai_right_angle(ai_right_angle[2]),
        .ai_action_cmd(ai_action_cmd[2]),
        .cmd_left_angle(cmd_left_angle1),
        .cmd_right_angle(cmd_right_angle1),
        .cmd_action_cmd(cmd_action_cmd1),
        //
        .delay(~player_selected[2]),
        .enable(~pause),
        .hold(player_hold[2]),
        .selected(player_selected[2]),
        .targeted(player_targeted[2]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[2]),
        .out_const(const_init[2]),
        .out_free(free_init[2]),
        .shoot_level(shoot_level[2]),
        .tackle_signal(tackle_signal[2]),
        .shoot_signal(shoot_signal[2]),
        .switch_signal(switch_signal[2])
    );

    player #(.PLAYER_INIT_X(PLAYER3_X), .PLAYER_INIT_Y(PLAYER3_Y),
    .PLAYER_INIT_ANGLE(18), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_3(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[3]),
        .ai_right_angle(ai_right_angle[3]),
        .ai_action_cmd(ai_action_cmd[3]),
        .cmd_left_angle(cmd_left_angle1),
        .cmd_right_angle(cmd_right_angle1),
        .cmd_action_cmd(cmd_action_cmd1),
        //
        .delay(~player_selected[3]),
        .enable(~pause),
        .hold(player_hold[3]),
        .selected(player_selected[3]),
        .targeted(player_targeted[3]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[3]),
        .out_const(const_init[3]),
        .out_free(free_init[3]),
        .shoot_level(shoot_level[3]),
        .tackle_signal(tackle_signal[3]),
        .shoot_signal(shoot_signal[3]),
        .switch_signal(switch_signal[3])
    );

    player #(.PLAYER_INIT_X(PLAYER4_X), .PLAYER_INIT_Y(PLAYER4_Y),
    .PLAYER_INIT_ANGLE(18), .XMIN(LEFT_KEEPER_X1), .XMAX(LEFT_KEEPER_X2), .YMIN(LEFT_KEEPER_Y1), .YMAX(LEFT_KEEPER_Y2), .KEEPER(1)
    )
    u_player_4(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[4]),
        .ai_right_angle(ai_right_angle[4]),
        .ai_action_cmd(ai_action_cmd[4]),
        .cmd_left_angle(cmd_left_angle1),
        .cmd_right_angle(cmd_right_angle1),
        .cmd_action_cmd(cmd_action_cmd1),
        //
        .delay(0),          // 门将不减速
        .enable(~pause),
        .hold(player_hold[4]),
        .selected(player_selected[4]),
        .targeted(player_targeted[4]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[4]),
        .out_const(const_init[4]),
        .out_free(free_init[4]),
        .shoot_level(shoot_level[4]),
        .tackle_signal(tackle_signal[4]),
        .shoot_signal(shoot_signal[4]),
        .switch_signal(switch_signal[4])
    );

    player #(.PLAYER_INIT_X(PLAYER5_X), .PLAYER_INIT_Y(PLAYER5_Y),
    .PLAYER_INIT_ANGLE(54), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_5(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[5]),
        .ai_right_angle(ai_right_angle[5]),
        .ai_action_cmd(ai_action_cmd[5]),
        .cmd_left_angle(cmd_left_angle2),
        .cmd_right_angle(cmd_right_angle2),
        .cmd_action_cmd(cmd_action_cmd2),
        //
        .delay(~player_selected[5]),
        .enable(~pause),
        .hold(player_hold[5]),
        .selected(player_selected[5]),
        .targeted(player_targeted[5]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[5]),
        .out_const(const_init[5]),
        .out_free(free_init[5]),
        .shoot_level(shoot_level[5]),
        .tackle_signal(tackle_signal[5]),
        .shoot_signal(shoot_signal[5]),
        .switch_signal(switch_signal[5])
    );

    player #(.PLAYER_INIT_X(PLAYER6_X), .PLAYER_INIT_Y(PLAYER6_Y),
    .PLAYER_INIT_ANGLE(54), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_6(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[6]),
        .ai_right_angle(ai_right_angle[6]),
        .ai_action_cmd(ai_action_cmd[6]),
        .cmd_left_angle(cmd_left_angle2),
        .cmd_right_angle(cmd_right_angle2),
        .cmd_action_cmd(cmd_action_cmd2),
        //
        .delay(~player_selected[6]),
        .enable(~pause),
        .hold(player_hold[6]),
        .selected(player_selected[6]),
        .targeted(player_targeted[6]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[6]),
        .out_const(const_init[6]),
        .out_free(free_init[6]),
        .shoot_level(shoot_level[6]),
        .tackle_signal(tackle_signal[6]),
        .shoot_signal(shoot_signal[6]),
        .switch_signal(switch_signal[6])
    );

    player #(.PLAYER_INIT_X(PLAYER7_X), .PLAYER_INIT_Y(PLAYER7_Y),
    .PLAYER_INIT_ANGLE(54), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_7(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[7]),
        .ai_right_angle(ai_right_angle[7]),
        .ai_action_cmd(ai_action_cmd[7]),
        .cmd_left_angle(cmd_left_angle2),
        .cmd_right_angle(cmd_right_angle2),
        .cmd_action_cmd(cmd_action_cmd2),
        //
        .delay(~player_selected[7]),
        .enable(~pause),
        .hold(player_hold[7]),
        .selected(player_selected[7]),
        .targeted(player_targeted[7]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[7]),
        .out_const(const_init[7]),
        .out_free(free_init[7]),
        .shoot_level(shoot_level[7]),
        .tackle_signal(tackle_signal[7]),
        .shoot_signal(shoot_signal[7]),
        .switch_signal(switch_signal[7])
    );

    player #(.PLAYER_INIT_X(PLAYER8_X), .PLAYER_INIT_Y(PLAYER8_Y),
    .PLAYER_INIT_ANGLE(54), .XMIN(LEFT_X), .XMAX(RIGHT_X), .YMIN(BOTTOM_Y), .YMAX(TOP_Y)
    )
    u_player_8(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[8]),
        .ai_right_angle(ai_right_angle[8]),
        .ai_action_cmd(ai_action_cmd[8]),
        .cmd_left_angle(cmd_left_angle2),
        .cmd_right_angle(cmd_right_angle2),
        .cmd_action_cmd(cmd_action_cmd2),
        //
        .delay(~player_selected[8]),
        .enable(~pause),
        .hold(player_hold[8]),
        .selected(player_selected[8]),
        .targeted(player_targeted[8]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[8]),
        .out_const(const_init[8]),
        .out_free(free_init[8]),
        .shoot_level(shoot_level[8]),
        .tackle_signal(tackle_signal[8]),
        .shoot_signal(shoot_signal[8]),
        .switch_signal(switch_signal[8])
    );

    player #(.PLAYER_INIT_X(PLAYER9_X), .PLAYER_INIT_Y(PLAYER9_Y),
    .PLAYER_INIT_ANGLE(54), .XMIN(RIGHT_KEEPER_X1), .XMAX(RIGHT_KEEPER_X2), .YMIN(RIGHT_KEEPER_Y1), .YMAX(RIGHT_KEEPER_Y2), .KEEPER(1)
    )
    u_player_9(
        .player_game_clk(game_clk),
        .rst(rst),
        .ai_left_angle(ai_left_angle[9]),
        .ai_right_angle(ai_right_angle[9]),
        .ai_action_cmd(ai_action_cmd[9]),
        .cmd_left_angle(cmd_left_angle2),
        .cmd_right_angle(cmd_right_angle2),
        .cmd_action_cmd(cmd_action_cmd2),
        //
        .delay(0),
        .enable(~pause),
        .hold(player_hold[9]),
        .selected(player_selected[9]),
        .targeted(player_targeted[9]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[9]),
        .out_const(const_init[9]),
        .out_free(free_init[9]),
        .shoot_level(shoot_level[9]),
        .tackle_signal(tackle_signal[9]),
        .shoot_signal(shoot_signal[9]),
        .switch_signal(switch_signal[9])
    );

    /*****************  足球 *********************/

    football #(.INIT_X(BALL_X1), .INIT_Y(BALL_Y))u_football(
        .football_game_clk(game_clk),
        .rst(rst),
        .football_pos(debug_number[11:0]),
        .pos_flag(pos_flag),
        .being_held(football_being_held),
        .const_init(football_const_init),
        .free_init(football_free_init),
        .ball_info(ball_info)  
    );


    /*************  预切换对象管理器 *********/
    // 
    logic [3:0] grp1_target;        //更新：target属性对于门将无效；对于非持球方，代表距离球最近的人
    logic [3:0] grp2_target;
    logic [31:0] dis[9:0];      // 人和球的距离
    logic [7:0] real_ang[9:0];          // 人和人的角度
    logic [7:0] aim_ang[9:0];        // real_ang和指示器的角度
    always_comb begin
        if(cmd_right_angle1 == 'hFF)begin   // 这种情况找距离最近的
            for(integer k=0; k<5; k=k+1)begin
                dis[k] = player_selected[k] ? 32'hffffffff : distance(player_info[k].x, player_info[k].y, ball_info.x, ball_info.y);
            end
            if      (dis[0] <= dis[1] && dis[0] <= dis[2] && dis[0] <= dis[3])  grp1_target = 0;
            else if (dis[1] <= dis[0] && dis[1] <= dis[2] && dis[1] <= dis[3])  grp1_target = 1;
            else if (dis[2] <= dis[0] && dis[2] <= dis[1] && dis[2] <= dis[3])  grp1_target = 2;
            else  grp1_target = 3;
        end else begin                      // 这种情况下找夹角最小的
            for(integer k=0; k<5; k=k+1)begin
                real_ang[k] = (player_selected[k]) ? 8'hFF :
                     vec2angle(player_info[player_selected_index1].x, player_info[player_selected_index1].y, player_info[k].x ,player_info[k].y);
            end
            for(integer k=0; k<5; k=k+1)begin
                aim_ang[k] = player_selected[k] ? 8'hff : rel_angle_val(real_ang[k], cmd_right_angle1);
            end
            if(aim_ang[0] <= aim_ang[1] && aim_ang[0] <= aim_ang[2] && aim_ang[0] <= aim_ang[3] )  grp1_target = 0;
            else if(aim_ang[1] <= aim_ang[0] && aim_ang[1] <= aim_ang[2] && aim_ang[1] <= aim_ang[3])  grp1_target = 1;
            else if(aim_ang[2] <= aim_ang[0] && aim_ang[2] <= aim_ang[1] && aim_ang[2] <= aim_ang[3])  grp1_target = 2;
            else   grp1_target = 3;
        end

        if(cmd_right_angle2 == 'hFF)begin
            for(integer k=5; k<10; k=k+1)begin
                dis[k] = player_selected[k] ? 32'hffffffff : distance(player_info[k].x, player_info[k].y, ball_info.x, ball_info.y);
            end

            if      (dis[5] <= dis[6] && dis[5] <= dis[7] && dis[5] <= dis[8])  grp2_target = 5;
            else if (dis[6] <= dis[5] && dis[6] <= dis[7] && dis[6] <= dis[8])  grp2_target = 6;
            else if (dis[7] <= dis[5] && dis[7] <= dis[6] && dis[7] <= dis[8])  grp2_target = 7;
            else grp2_target = 8;
        end else begin
            for(integer k=0; k<5; k=k+1)begin
                real_ang[k+5] = (player_selected[k+5]) ? 8'hFF :
                    vec2angle(player_info[player_selected_index2].x, player_info[player_selected_index2].y, player_info[k+5].x ,player_info[k+5].y);
            end
            for(integer k=0; k<5; k=k+1)begin
                aim_ang[k+5] = player_selected[k+5] ? 8'hff : rel_angle_val(real_ang[k+5], cmd_right_angle2);
            end
            if(aim_ang[5] <= aim_ang[6] && aim_ang[5] <= aim_ang[7] && aim_ang[5] <= aim_ang[8] )  grp2_target = 5;
            else if(aim_ang[6] <= aim_ang[5] && aim_ang[6] <= aim_ang[7] && aim_ang[6] <= aim_ang[8] )  grp2_target = 6;
            else if(aim_ang[7] <= aim_ang[5] && aim_ang[7] <= aim_ang[6] && aim_ang[7] <= aim_ang[8] )  grp2_target = 7;
            else grp2_target = 8;
        end
    end

    always_comb begin
        if(grp1_target==0)begin
            player_targeted[4:0] <= 5'b00001;
        end else if(grp1_target==1)begin
            player_targeted[4:0] <= 5'b00010;
        end else if(grp1_target==2)begin
            player_targeted[4:0] <= 5'b00100;
        end else if(grp1_target==3)begin
            player_targeted[4:0] <= 5'b01000;
        end else begin
            player_targeted[4:0] <= 5'b00000;
        end
        if(grp2_target==5)begin
            player_targeted[9:5] <= 5'b00001;
        end else if(grp2_target==6)begin
            player_targeted[9:5] <= 5'b00010;
        end else if(grp2_target==7)begin
            player_targeted[9:5] <= 5'b00100;
        end else if(grp2_target==8)begin
            player_targeted[9:5] <= 5'b01000;
        end else begin
            player_targeted[9:5] <= 5'b00000;
        end
    end
    /************* 控制器   **************/
    object_controller u_object_controller(
        .controller_game_clk(game_clk),
        .rst(rst),
        .pos_flag(pos_flag),
        .tackle_signal(tackle_signal),
        .shoot_signal(shoot_signal), 
        .switch_signal(switch_signal),
        .in_const(const_init),
        .in_free(free_init),
        .grp1_target(grp1_target),
        .grp2_target(grp2_target),
        .ulti_const_init(football_const_init),
        .ulti_free_init(football_free_init),
        .football_being_held(football_being_held),
        .player_hold(player_hold),
        .player_selected(player_selected),
        .player_selected_index1(player_selected_index1),
        .player_selected_index2(player_selected_index2),
        .player_hold_index(player_hold_index)
    );
endmodule