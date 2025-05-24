module game(
    input game_clk,     // 游戏帧
    input ps2_clk,
    input rst,

    output reg [31:0] debug_number,


    // ps2接口
    output wire pmod_io1,
    input wire pmod_io2,
    output wire pmod_io3,
    output reg pmod_io4
);
    //应该也是一个状态机，而不是连续的逻辑，否则可能没有足够的时间来完成

    //读取cmd

    //AI球员，需要根据读取的cmd来决策（而且读取的cmd中有些具有最高优先级，能够打断独立的AI决策）

    //类对象更迭，球员，球...（主要是对运动的处理）

    //渲染模块(双缓冲)，并不一定每一帧都要处理     频率更慢，实现50帧


    /******************  变量定义       *******************/

    //cmd解码器输出的控制信号
    reg [7:0] tmp_la;
    reg [7:0] tmp_ra;
    reg [5:0] tmp_ac;

    // 1号球员输出的位置、状态信号
    reg [15:0] x1;
    reg [15:0] y1;
    reg [15:0] z1;
    reg [7:0] angle_1;
    reg [7:0] speed_1;
    reg [7:0] anim_stat_1;
    //1号状态机的信号
    reg A_enable_1;
    reg A_signal_1;
    reg W_enable_1;
    reg W_signal_l;
    constrained_init const_1;
    free_init free_1;

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
    //总控制器信号

    reg [15:0] tackle_signal;      //抢断信号
    reg [15:0] shoot_signal;        //射门信号
    reg [15:0] player_hold_stat;        //最终的结果，谁持球
    reg football_being_held;    //是否被持球

    

    /******************  手柄控制器 1   *******************/
    
    cmd_decoder u_cmd_decoder(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod_io1),
        .pmod_io2(pmod_io2),
        .pmod_io3(pmod_io3),
        .pmod_io4(pmod_io4),
        .left_angle(tmp_la),
        .right_angle(tmp_ra),
        .action_command2(tmp_ac),
    );
    
    /***************** 球员 *******************/
    

    player u_player_1(
        .game_clk(game_clk),
        .rst(rst),
        .A_enable(A_enable_1),
        .A_signal(A_signal_1),
        .W_enable(W_enable_1),
        .W_signal(W_signal_1),
        // out
        .hold(player_hold_stat[0]),
        .pos_x(x1),
        .pos_y(y1),
        .pos_z(z1),
        .angle(angle_1),
        .speed(speed_1),
        .anim_stat(anim_stat_1)
    );

    /****************   球员状态机   ******************/
    HFSM u_HFSM_1(
        .game_clk(game_clk),
        .rst(rst),
        .hold(player_hold_stat[0]),
        .player_tackle_signal(tackle_signal[0]),
        .player_shoot_signal(shoot_signal[0]),
    );

    /*****************  足球 *********************/

    football u_football(
        .game_clk(clock),
        .rst(reset),
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
        .pos_x(pos_x),
        .pos_y(pos_y),
        .pos_z(pos_z)        
    );
    /************* 控制器   **************/
    controller u_controller(
        .game_clk(game_clk),
        .rst(rst),
        .player_hold_stat(player_hold_stat),
        .tackle_signal(tackle_signal),
        .shoot_signal(shoot_signal),

        .in_const_1(const_1),
        .in_free_1(free_1),


        .football_being_held(football_being_held),
        .master_x(master_x),
        .master_y(master_y),
        .master_height(master_height),
        .master_angle(master_angle),
        .master_radius(master_radius),
        .init_angle(init_angle),
        .init_speed(init_speed),
        .init_vertical_speed(init_vertical_speed),
        .init_vertical_signal(init_vertical_signal),

    );
    
endmodule