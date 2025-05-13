`timescale 1ns/1ps
module game_tb();
    reg game_clk;
    reg rst;
        /******************  变量定义       *******************/
    //足球信号
    reg [15:0] football_pos_x;
    reg [15:0] football_pos_y;
    reg [15:0] football_pos_z;
    reg [15:0] master_x;
    reg [15:0] master_y;
    reg [15:0] master_height;
    reg [7:0] master_angle;
    reg [15:0] master_radius;
    reg [7:0] init_angle;
    reg [7:0] init_speed;
    reg [7:0] init_vertical_speed;
    reg init_vertical_signal;

    // 1号球员输出的位置、状态信号
    reg [15:0] x1;
    reg [15:0] y1;
    reg [7:0] angle_1;
    reg [7:0] speed_1;
    reg [7:0] anim_stat_1;
    //1号状态机的信号
    reg A_enable_1;
    reg A_signal_1;
    reg W_enable_1;
    reg W_signal_1;
    constrained_init const_1();
    free_init free_1();
    player_info pinfo1(x1,y1,angle_1,speed_1);

    // 6号球员输出的位置、状态信号
    reg [15:0] x6;
    reg [15:0] y6;
    reg [7:0] angle_6;
    reg [7:0] speed_6;
    reg [7:0] anim_stat_6;

    //6号状态机的信号
    reg A_enable_6;
    reg A_signal_6;
    reg W_enable_6;
    reg W_signal_6;
    constrained_init const_6();
    free_init free_6();
    player_info pinfo6(x6,y6,angle_6,speed_6);

    //总控制器信号

    reg [15:0] tackle_signal;      //抢断信号
    reg [15:0] shoot_signal;        //射门信号
    reg [15:0] player_hold_stat;        //最终的结果，谁持球
    reg football_being_held;    //是否被持球

    /***************** 球员 *******************/
    

    player #(80, 100, 2, 0)u_player_1(
        .player_game_clk(game_clk),
        .rst(rst),
        .A_enable(A_enable_1),
        .A_signal(A_signal_1),
        .W_enable(W_enable_1),
        .W_signal(W_signal_1),
        // out
        .hold(player_hold_stat[0]),
        .pos_x(x1),
        .pos_y(y1),
        .angle(angle_1),
        .speed(speed_1),
        .anim_stat(anim_stat_1)
    );

    /****************   球员状态机   ******************/
    HFSM #( .INIT_STAT(2) )u_HFSM_1(
        .HFSM_game_clk(game_clk),
        .rst(rst),
        .hold(player_hold_stat[0]),
        .player_tackle_signal(tackle_signal[0]),
        .player_shoot_signal(shoot_signal[0]),
        .player_x(x1),
        .player_y(y1),
        .player_speed(speed_1),
        .player_angle(angle_1),
        .football_x(football_pos_x),
        .football_y(football_pos_y),
        .football_z(football_pos_z),
        .A_enable(A_enable_1),
        .A_signal(A_signal_1),
        .W_enable(W_enable_1),
        .W_signal(W_signal_1),
        .const_ball_parameter(const_1),
        .free_ball_parameter(free_1)
    );

    /*****************  足球 *********************/

    football u_football(
        .football_game_clk(game_clk),
        .rst(rst),
        .being_held(football_being_held),
        .master_x(master_x),
        .master_y(master_y),
        .master_height(master_height),
        .master_angle(master_angle),
        .master_radius(master_radius),
        .init_angle(init_angle),
        .init_speed(init_speed),
        .init_vertical_speed(init_vertical_speed),
        .init_vertical_signal(init_vertical_signal),
        .pos_x(football_pos_x),
        .pos_y(football_pos_y),
        .pos_z(football_pos_z)        
    );
    /************* 控制器   **************/
    controller u_controller(
        .controller_game_clk(game_clk),
        .rst(rst),
        .player_hold_stat(player_hold_stat),
        .tackle_signal(tackle_signal),
        .shoot_signal(shoot_signal),

        .in_const_1(const_1),
        .in_free_1(free_1),
        .in_const_6(const_6),
        .in_free_6(free_6),

        .football_being_held(football_being_held),
        .master_x(master_x),
        .master_y(master_y),
        .master_height(master_height),
        .master_angle(master_angle),
        .master_radius(master_radius),
        .init_angle(init_angle),
        .init_speed(init_speed),
        .init_vertical_speed(init_vertical_speed),
        .init_vertical_signal(init_vertical_signal)

    );
    integer i;
    integer rand_r;
    integer rand_angle;
    initial begin
        rst = 1'b0;       // 手动模拟时钟
        tackle_signal <= 16'd0;
        shoot_signal <= 16'd0;
        player_hold_stat <= 16'd0;
        football_being_held <= 1'b0;
        game_clk = 1'b0;
        #100
        rst = 1'b1;
        #100
        rst = 1'b0;
        

        $finish;
    end

    always #5 game_clk = ~game_clk; // 100MHz

endmodule
