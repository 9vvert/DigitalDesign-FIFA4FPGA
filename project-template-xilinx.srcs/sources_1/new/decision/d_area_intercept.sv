import type_declare::*;
module area_intercept
// FOLLOW_FORCE设置的很大，意味着不容易被影响
#(parameter FOLLOW_FORCE=20)
(
    input PlayerInfo self_info,
    // 从P1到P2
    input [11:0] x1,
    input [11:0] y1,
    input [7:0] ang1,
    input [7:0] ang2,
    //
    output wire [2:0] force_level,       //斥力等级
    //
    output reg enable_sprint,
    output reg[11:0] area_intercept_x_pos,     //向目标牵引
    output reg[11:0] area_intercept_x_neg,
    output reg[11:0] area_intercept_y_pos,
    output reg[11:0] area_intercept_y_neg

);
    import LineLib::*;
    import TrianglevalLib::*;
    // 不需要严格朝着某个定点移动，只需要在这个区域内就行
    assign force_level = 3;
    import TrianglevalLib::*;
    // 同样简化为矩形区域
    logic [7:0] inter_angle;
    logic [11:0] aim_x;
    logic [11:0] aim_y;     // 校准坐标
    logic [11:0] aim_dis;
    always_comb begin

        inter_angle = ((ang1 + ang2) >> 1); //简化：取角平分线
        //计算校准点
        //  15*12 = R
        if(inter_angle < 8'd18) begin
            aim_x <= x1 + 15*sin(inter_angle);
            aim_y <= y1 + 15*cos(inter_angle);
        end else if(inter_angle < 8'd36) begin
            aim_x <= x1 + 15*cos(inter_angle - 8'd18);
            aim_y <= y1 - 15*sin(inter_angle - 8'd18);
        end else if(inter_angle < 8'd54) begin
            aim_x <= x1 - 15*sin(inter_angle - 8'd36);
            aim_y <= y1 - 15*cos(inter_angle - 8'd36);
        end else if(inter_angle < 8'd72)begin
            aim_x <= x1 - 15*cos(inter_angle - 8'd54);
            aim_y <= y1 + 15*sin(inter_angle - 8'd54);
        end else begin
            aim_x <= x1;
            aim_y <= y1;
        end 

        aim_dis = distance(self_info.x, self_info.y, aim_x, aim_y);
        if(aim_dis > 22500)begin
            enable_sprint = 1;
        end else begin
            enable_sprint = 0;
        end

        // aim_x, aim_y的矩形区域
        // x
        if(self_info.x + 50 < aim_x)begin
            area_intercept_x_pos = 200;
            area_intercept_x_neg = 0;
        end else if(self_info.x > aim_x + 50)begin
            area_intercept_x_pos = 0;
            area_intercept_x_neg = 200;
        end else begin
            area_intercept_x_pos = 0;
            area_intercept_x_neg = 0;
        end
        // y
        if(self_info.y + 50 < aim_y)begin
            area_intercept_y_pos = 200;
            area_intercept_y_neg = 0;
        end else if(self_info.y > aim_y + 50)begin
            area_intercept_y_pos = 0;
            area_intercept_y_neg = 200;
        end else begin
            area_intercept_y_pos = 0;
            area_intercept_y_neg = 0;
        end
    end
endmodule