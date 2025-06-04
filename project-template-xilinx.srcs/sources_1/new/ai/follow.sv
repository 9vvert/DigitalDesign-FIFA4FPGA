/************  首个AI模块，向一个目标点移动  ************/

module follow
#(parameter V_MAX = 4, V1 = 3, V2 = 2, V3 = 1, V4 = 0)
(
    input game_clk,
    input rst,
    input enable,       // 只在enable = 1时工作，而且会实时读取obj_angle, obj_speed, aim_speed的数值
    input PlayerInfo self_info,
    input [11:0] aim_x,
    input [11:0] aim_y,
    //输出的控制信号
    output reg [7:0] follow_left_angle         // 模拟左摇杆输入
    // output MoveControl follow_ctrl
);
import AngleLib::*;
import TrianglevalLib::*;
import LineLib::*;

    always_comb begin
        if(enable && (self_info.x != aim_x) && (self_info.y != aim_y))begin
            follow_left_angle = vec2angle(self_info.x,self_info.y,aim_x,aim_y);
        end else begin
            follow_left_angle = 'hFF;           // 其余情况下，相当于没有摇杆
        end
    end

endmodule