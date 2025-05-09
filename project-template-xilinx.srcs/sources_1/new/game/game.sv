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



    // cmd decoder
    //[TODO]估算读取一次手柄命令所需要的时间，进而设计游戏时钟频率

    // HFSM, 每一个对象都有自己的自动机

    // AI_controller
    //

    // 对象，足球、运动员等
    reg [15:0] x1;
    reg [15:0] y1;
    reg [15:0] z1;
    reg [7:0] angle_1;
    reg [7:0] speed_1;
    reg [7:0] anim_stat_1;       //用于描绘动画
    reg[7:0] left_angle;
    reg[7:0] right_angle;
    reg[5:0] action;

    reg [7:0] tmp_la;
    reg [7:0] tmp_ra;
    reg [5:0] tmp_ac;

    cmd_decoder u_cmd_decoder(
        .ps2_clk(ps2_clk),
        .rst(rst),
        .pmod_io1(pmod_io1),
        .pmod_io2(pmod_io2),
        .pmod_io3(pmod_io3),
        .pmod_io4(pmod_io4),
        .left_angle(tmp_la),
        .right_angle(tmp_ra),
        .action_command(tmp_ac),
    );
    always @(posedge game_clk) begin
        if(rst) begin
            debug_number <= 32'd0;
        end else begin
            //从ps2_clk过渡到game_clk
            left_angle <= tmp_la;
            right_angle <= tmp_ra;
            action_command <= tmp_ac;
            if(cmd_ready) begin
                debug_number[7:0] <= right_angle;
                debug_number[15:8] <= left_angle;
                debug_number[23:16] <= left_X;
                debug_number[31:24] <= left_Y;
            end else begin
                debug_number <= debug_number;
            end
        end
    end
    // 实例化球员
    player u_player_1(
        .game_clk(game_clk),
        .rst(rst),
        .left_angle(left_angle),
        .right_angle(right_angle),
        .action_cmd(action_command),
        // out
        .pos_x(x1),
        .pos_y(y1),
        .pos_z(z1),
        .angle(angle_1),
        .speed(speed_1),
        .anim_stat(anim_stat_1)
    );
    
endmodule