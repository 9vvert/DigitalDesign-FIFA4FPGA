import type_declare::PlayerInfo, type_declare::BallInfo;
module fake_game(
    input game_clk,     // 游戏帧
    input ps2_clk,
    input rst,
    output [31:0]debug_number,
    // ps2接口
    output wire pmod_io1,
    input wire pmod_io2,
    output wire pmod_io3,
    output reg pmod_io4,
    //game需要向外输出的是： bg, 渲染组件
    //不需要通讯协议，持续输出，等显存准备好了就会渲染
    output PlayerInfo player_info[9:0],
    output BallInfo ball_info,
    output reg [5:0] game_bg      // 当前的场景
);
    /******************  变量定义       *******************/

    //cmd解码器输出的控制信号
    reg [7:0] cmd_left_angle;
    reg [7:0] cmd_right_angle;
    reg [7:0] cmd_action_cmd;
    //
    ConstrainedInit const_init[9:0];
    ConstrainedInit football_const_init;
    FreeInit football_free_init;
    FreeInit free_init [9:0];
    
    //总控制器输入
    wire [9:0] tackle_signal;
    wire [9:0] shoot_signal;
    wire [3:0]switch_signal[9:0];      // 正常情况下，应该为0；真正有效的信号范围是1-10
    //总控制器输出
    wire football_being_held;
    wire [9:0] player_hold;
    wire [9:0] player_selected;
    /////////////////////  为了测试，部分player_info赋一个值




    /******************  手柄控制器 1   *******************/
    reg [7:0] cmd_left_angle;
    initial begin
        cmd_left_angle = 9;
        #1000000;
        cmd_left_angle = 8'hFF;
    end
    cmd_decoder u_cmd_decoder(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod_io1),
        .pmod_io2(pmod_io2),
        .pmod_io3(pmod_io3),
        .pmod_io4(pmod_io4),
        .right_angle(cmd_right_angle),
        .action_cmd2(cmd_action_cmd)        //已经完成消抖
    );
    assign debug_number[7:0] = cmd_action_cmd;
    assign debug_number[15:8] = cmd_left_angle;
    assign debug_number[23:16] = cmd_right_angle;
    /***************** 球员 *******************/
    
    player #(.PLAYER_INIT_X(128), .PLAYER_INIT_Y(128))
    u_player_1(
        .player_game_clk(game_clk),
        .rst(rst),
        .cmd_left_angle(cmd_left_angle),
        .cmd_right_angle(cmd_right_angle),
        .cmd_action_cmd(cmd_action_cmd),
        //
        .hold(player_hold[0]),
        .selected(player_selected[0]),
        // out
        .ball_info(ball_info),
        .self_info(player_info[0]),
        .out_const(const_init[0]),
        .out_free(free_init[0])
    );

    /*****************  足球 *********************/

    football u_football(
        .football_game_clk(game_clk),
        .rst(rst),
        .being_held(football_being_held),
        .const_init(football_const_init),
        .free_init(football_free_init),
        .ball_info(ball_info)  
    );
    /************* 控制器   **************/
    object_controller u_object_controller(
        .controller_game_clk(game_clk),
        .rst(rst),
        .tackle_signal(tackle_signal),
        .shoot_signal(shoot_signal), 
        .switch_signal(switch_signal),
        .in_const(const_init),
        .in_free(free_init),
        .ulti_const_init(football_const_init),
        .ulti_free_init(football_free_init),
        .football_being_held(football_being_held),
        .player_hold(player_hold),
        .player_selected(player_selected)
    );

    always@(posedge game_clk)begin
        if(rst)begin
            game_bg <= 0;   // 0号背景
        end else begin
            game_bg <= game_bg;
            for(integer i=1; i<10; i= i+1)begin
                player_info[i].x <= 0;
                player_info[i].y <= 0;
                player_info[i].angle <= 0;
                player_info[i].speed <= 0;
                player_info[i].index <= i;
                player_info[i].anim_stat <= 1;
            end
        end
    end
endmodule