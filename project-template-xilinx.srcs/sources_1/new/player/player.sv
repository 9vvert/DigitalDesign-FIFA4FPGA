// 足球运动员模块

// [TODO]如何选择游戏时钟的频率？

// [TODO]命令的优先级应该在ps2_decode过程中就完成，在这里已经是没有歧义的命令，一次至多执行一个A类动作（B类奔跑独立）

// 在实际应用的时候，需要把 v / a等转化为周期，需要设置一个参数
module player(
    input game_clk,           //和游戏时钟频率相同
    input rst, 

    input [7:0] left_angle,
    input [7:0] right_angle,
    input [5:0] action_cmd,
    //输出，用于 1.渲染  2.模块之间交互 3.AI参数
    output reg [15:0] pos_x,
    output reg [15:0] pos_y,
    output reg [15:0] pos_z,
    output reg [7:0] angle,
    output reg [7:0] speed,

    output reg [7:0] anim_stat  //用于渲染不同的运动员动作
    // 迈开腿这样的状态机切换频率，应该和人物的速度挂钩
);
    reg A_enable;
    reg A_signal;
    reg W_enable;
    reg W_signal;

    // "run"部分，除了会受到转弯/动作的影响，其它情况下应该是能够独立完成的

    /****************   坐标计算  *******************/
    position_caculator u_position_caculator(
        .game_clk(game_clk),
        .rst(rst),
        .in_angle(angle),
        .in_speed(speed),
        .out_x(pos_x),
        .out_y(pos_y)
    );

    /***************** 速度计算****************/
    speed_caculator u_speed_caculator(
        .game_clk(game_clk),
        .rst(rst),
        .enable(A_enable),
        .signal(A_signal),
        .speed(speed)
    );

    /**************** 角度计算 *****************/
    angle_caculator u_angle_cacluator(
        .game_clk(game_clk),
        .rst(rst),
        .enable(W_enable),
        .signal(W_signal),
        .angle(angle)
    );

    always @(posedge game_clk) begin
        if(rst) begin

        end else begin

        end
    end
endmodule