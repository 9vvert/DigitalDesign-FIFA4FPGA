import type_declare::*;
module line_intercept
// FOLLOW_FORCE设置的很大，意味着不容易被影响
#(parameter FOLLOW_FORCE=20)
(
    input PlayerInfo self_info,
    // 从P1到P2
    input [11:0] x1,
    input [11:0] y1,
    input [11:0] x2,
    input [11:0] y2,
    //
    output wire [2:0] force_level,       //斥力等级
    //
    output enable_sprint,
    output [11:0] line_intercept_x_pos,     //向目标牵引
    output [11:0] line_intercept_x_neg,
    output [11:0] line_intercept_y_pos,
    output [11:0] line_intercept_y_neg

);
    import LineLib::*;
    // 简化：用中点
    logic [11:0] mid_x;
    logic [11:0] mid_y;
    logic [7:0] mid_angle;
    logic [11:0] mid_dis;

    assign force_level = 3;

    always_comb begin
        mid_x = (x1 + x2)>>1;
        mid_y = (y1 + y2)>>1;
        mid_dis = distance(self_info.x, self_info.y, midx, mid_y);
        if(mid_dis > 22500)begin
            enable_sprint = 1;
        end else begin
            enable_sprint = 0;
        end
        
        // x
        if(self_info.x + 50 < mid_x)begin
            line_intercept_x_pos = 200;
            line_intercept_x_neg = 0;
        end else if(self_info.x > mid_x + 50)begin
            line_intercept_x_pos = 0;
            line_intercept_x_neg = 200;
        end else begin
            line_intercept_x_pos = 0;
            line_intercept_x_neg = 0;
        end
        // y
        if(self_info.y + 50 < mid_y)begin
            line_intercept_y_pos = 200;
            line_intercept_y_neg = 0;
        end else if(self_info.y > mid_y + 50)begin
            line_intercept_y_pos = 0;
            line_intercept_y_neg = 200;
        end else begin
            line_intercept_y_pos = 0;
            line_intercept_y_neg = 0;
        end
        
    end


endmodule