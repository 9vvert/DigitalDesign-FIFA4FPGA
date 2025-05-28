// 足球模块
/*****************  使用约定  ******************/
//外界在保持being_held为高电平的时候，必须在每回合都传入master_* 这几个参数
//在为低电平的时候，必须提供init_* 这几个参数的初始值
import type_declare::BallInfo, type_declare::ConstrainedInit, type_declare::FreeInit;
module football
#(parameter INIT_X = 100, INIT_Y = 100, INIT_Z = 0)
(
    input football_game_clk,           //和游戏时钟频率相同
    input rst, 

    input being_held,       // 是否被持球（0代表自由状态，1代表被持球）
    // 在束缚状态下，其位置仅仅由外部输入决定(输入：master的坐标，球的角度，人和球的距离，计算出球的坐标)
    input ConstrainedInit const_init,
    // 在自由状态下，其运动由物理引擎驱动，但是初始可以赋予一个初速度，并自由决定方向（射门、传球过程）
    input FreeInit free_init,
    // 最终的输出
    output BallInfo ball_info
    
);
import TrianglevalLib::*;
    wire [11:0] pos_x;
    wire [11:0] pos_y;
    wire [11:0] pos_z;
    wire [7:0] speed;
    wire [7:0] angle;
    wire [7:0] vertical_speed;
    reg vertical_signal;

    reg [11:0] free_x;
    reg [11:0] free_y;
    reg [11:0] free_z;
    assign pos_x = being_held ? const_init.master_x : free_x;
    assign pos_y = being_held ? const_init.master_y : free_y;
    assign pos_z = being_held ? const_init.master_height : free_z;
    assign speed = being_held ? 0 : free_init.init_speed;
    assign angle = being_held ? const_init.master_angle : free_init.init_angle;
    assign vertical_speed = being_held ? 0 : free_init.init_vertical_speed;
    assign vertical_signal = being_held ? 0 : free_init.init_vertical_signal;
    always_comb begin
        ball_info.anim_stat = 1;
        ball_info.x = pos_x;
        ball_info.y = pos_y;
        ball_info.z = pos_z;
        ball_info.speed = speed;
        ball_info.angle = 0;        // [TODO]修改多驱动问题后，football angle变成了高阻态，这里暂时用0代替
        ball_info.vertical_speed = vertical_speed;
        ball_info.vertical_signal = vertical_signal;
    end

    // 使用being_held作为set_enable使能，也就是在
    position_caculator #(.INIT_X(INIT_X), .INIT_Y(INIT_Y)) u_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_angle(angle),          // angle保持不变
        .in_speed(speed),
        .out_x(free_x),
        .out_y(free_y),
        .set_pos_enable(being_held),
        .set_x_val(const_init.master_x),              
        .set_y_val(const_init.master_y)
    );
    vertical_position_caculator u_vertical_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_vertical_speed(vertical_speed),
        .in_vertical_signal(vertical_signal),
        .out_z(free_z),
        .set_pos_enable(being_held),
        .set_z_val(const_init.master_height)
    );

    /***************** 速度计算****************/
    reg A_enable;
    reg A_signal;
    reg VA_enable;  //垂直加速度使能
    speed_caculator u_speed_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(A_enable),
        .signal(A_signal),
        .speed(speed),
        .set_speed_enable(being_held),
        .set_speed_val(free_init.init_speed)
    );
    vertical_speed_caculator u_vertical_speed_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(VA_enable),         // 这里不用加速度方向（重力加速度恒向下）
        .speed_signal(vertical_signal),
        .speed(vertical_speed),
        .set_speed_enable(being_held),
        .set_speed_val(free_init.init_vertical_speed),
        .set_speed_signal(free_init.init_vertical_signal)
    );
endmodule   