import type_declare::*;
// 2025.5.31
// 简化规则：让球员和持球者处于矩形区域中
module d_forward
#(parameter TEAM=0)
(
    input PlayerInfo self_info,
    input PlayerInfo holder_info,       // 上层决策树保证holder_info是自己同队的持球者
    output [2:0] force_level, 
    output reg [11:0] forward_x_pos,
    output reg [11:0] forward_x_neg,
    output reg [11:0] forward_y_pos,
    output reg [11:0] forward_y_neg
);
    assign force_level = 2;
    // x方向的值应该领先持球者75-225的距离；如果已经在区域内，就暂时消除这个力

    // 水平方向上，整体移动
    always_comb begin
        /******水平方向的力  ******/
        if(TEAM==0)begin        //向右出击
            if(self_info.x < holder_info.x)begin
                forward_x_pos = 150;
                forward_x_neg = 0;
            end else if(holder_info + 225 < self_info.x)begin
                forward_x_pos = 0;
                forward_x_neg = 150;
            end else begin
                forward_x_pos = 0;
                forward_x_neg = 0;
            end
        end else begin
            if(self_info.x > holder_info.x)begin
                forward_x_pos = 0;
                forward_x_neg = 150;
            end else if(self_info.x + 225 < holder_info.x)begin
                forward_x_pos = 150;
                forward_x_neg = 0;
            end else begin
                forward_x_pos = 0;
                forward_x_neg = 0;
            end
        end

        /******* 竖直方向的力*******/
        if(holder_info.y + 150 < self_info.y)begin
            forward_y_pos = 0;
            forward_y_neg = 150;
        end else if(self_info.y + 150 < holder_info.y)begin
            forward_y_pos = 150;
            forward_y_neg = 0;
        end else begin
            forward_y_pos = 0;
            forward_y_neg = 0;
        end
    end

endmodule