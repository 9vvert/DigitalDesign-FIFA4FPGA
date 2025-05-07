`timescale 1ns / 1ps

module angle_tb();
    `include "trangleval.sv"

    integer i;
    integer j;
    reg [7:0] ang;
    reg [7:0] ang1;
    reg [7:0] ang2;

    reg [7:0] add;
    reg [7:0] sub;
    reg [7:0] rel_val;
    reg [1:0] rel_pos;

    reg [15:0] x;
    reg [15:0] y;
    reg [9:0] sin_value;
    reg [9:0] cos_value;
    reg [9:0] tan_value;

    initial begin
        // 打印标题
        for (i = 0; i < 256; i = i + 1) begin
            for(j = 0; j< 256; j = j + 1) begin
                //仿真中用  = 而不是 <=
                x = i;
                y = j;
                
                ang = vec2angle(0, 0, x, y);
                sin_value = sin(ang);
                cos_value = cos(ang);
                tan_value = tan(ang);
                #1; // 每次间隔 10 时间单位
            end
        end

        // 结束模拟
        $finish;
    end
endmodule