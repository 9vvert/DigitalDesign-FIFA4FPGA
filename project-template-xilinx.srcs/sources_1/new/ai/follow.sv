/************  首个AI模块，向一个目标点移动  ************/

module follow
#(parameter V_MAX = 4, V1 = 3, V2 = 2, V3 = 1, V4 = 0)
(
    input game_clk,
    input rst,
    input enable,       // 只在enable = 1时工作，而且会实时读取obj_angle, obj_speed, aim_speed的数值
    input [15:0] obj_x,
    input [15:0] obj_y,
    input [7:0] obj_angle,
    input [7:0] obj_speed,
    input [15:0] aim_x,
    input [15:0] aim_y,
    //输出的控制信号
    output reg A_enable,
    output reg A_signal,
    output reg W_enable,
    output reg W_signal
);
import AngleLib::*;
import TrianglevalLib::*;
import LineLib::*;
    reg [7:0] mid_angle;        //连线的角
    reg [7:0] current_speed_max;
    reg [1:0] rel_pos;
    reg [7:0] rel_val;
    always @(posedge game_clk)begin
        if(rst)begin
            A_enable <= 1'b0;
            A_signal <= 1'b0;
            W_enable <= 1'b0;
            W_signal <= 1'b0;
            current_speed_max <= 8'd4;  //初始默认为4

        end else if(enable)begin
            mid_angle = vec2angle(obj_x,obj_y,aim_x,aim_y);
            rel_pos = rel_angle_pos(obj_angle, mid_angle);
            rel_val = rel_angle_val(obj_angle, mid_angle);
            //角度
            if(rel_pos == 2'd2)begin
                W_enable <= 1'b0;
            end else if(rel_pos == 2'd0) begin
                W_enable <= 1'b1;
                W_signal <= 1'b1;
            end else begin
                W_enable <= 1'b1;
                W_signal <= 1'b0;
            end
            //
            if(rel_val < 9)begin
                if(obj_speed < V1)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b0;
                end else if(obj_speed > V1)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b1;
                end else begin
                    A_enable <= 1'b0;
                end
            end else if(rel_val < 18)begin
                if(obj_speed < V2)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b0;
                end else if(obj_speed > V2)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b1;
                end else begin
                    A_enable <= 1'b0;
                end
            end else if(rel_val < 27)begin
                if(obj_speed < V3)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b0;
                end else if(obj_speed > V3)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b1;
                end else begin
                    A_enable <= 1'b0;
                end
            end else begin
                if(obj_speed < V4)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b0;
                end else if(obj_speed > V4)begin
                    A_enable <= 1'b1;
                    A_signal <= 1'b1;
                end else begin
                    A_enable <= 1'b0;
                end
            end
        end else begin
            W_enable <= 1'b0;
            A_enable <= 1'b0;
        end
    end
endmodule