`timescale 1ns/1ps
module football_tb();

    reg clock;
    reg reset;

    reg being_held;
    reg [15:0] master_x;
    reg [15:0] master_y;
    reg [15:0] master_height;     //外界输入的高度，用来直接设置球的高度
    reg [7:0] master_angle;
    reg [15:0] master_radius;     // radius自带12倍率（和sin; cos中的倍率一致）
    // 在自由状态下，其运动由物理引擎驱动，但是初始可以赋予一个初速度，并自由决定方向（射门、传球过程）
    reg [7:0] init_angle;
    reg [7:0] init_speed;
    reg [7:0] init_vertical_speed;
    reg init_vertical_signal;
    // 最终的输出
    reg [15:0] pos_x;
    reg [15:0] pos_y;
    reg [15:0] pos_z;

    football u_football(
        .game_clk(clock),
        .rst(reset),
        .being_held(being_held),
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

    integer i;
    integer rand_r;
    integer rand_angle;
    initial begin
        being_held = 1;       
        master_x = 0;
        master_y = 0;
        master_height = 0;  
        reset = 1'b0;       // 手动模拟时钟
        clock = 1'b0;
        #100
        reset = 1'b1;
        #100
        reset = 1'b0;
        
        being_held = 0;
        init_speed = 3;
        init_angle = 9;
        init_vertical_speed = 0;
        init_vertical_signal = 0;

        $finish;
    end

    always #5 clock = ~clock; // 100MHz
endmodule
