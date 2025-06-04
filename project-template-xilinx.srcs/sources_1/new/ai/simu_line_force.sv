// 模拟线的力场
import type_declare::*;
// 将obj_info为中心分为5个换，每次R + 20
module simu_line_force
#(parameter LINE_X=720, LINE_Y=1280)
(
    input PlayerInfo self_info,
    input enable,           // 是否启用
    // 简化：用固定的斥力，只不过有时候可能会用enable来关闭(比如抢球的时候，不能因为球靠墙而不去捡球)
    input mode,         // mode=0为竖线，mode=1为横线
    //输出作用力
    output reg [11:0] simu_x_pos,
    output reg [11:0] simu_x_neg,
    output reg [11:0] simu_y_pos,
    output reg [11:0] simu_y_neg
);
    logic [11:0] dis;
    always_comb begin
        if(mode == 0)begin
            if(self_info.x >= LINE_X)begin
                dis = self_info.x - LINE_X;
                if(dis < 20)begin
                    simu_x_pos = 300;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end else if(dis < 40)begin
                    simu_x_pos = 150;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end else begin 
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end
            end else begin
                dis = LINE_X - self_info.x;
                if(dis < 20)begin
                    simu_x_pos = 0;
                    simu_x_neg = 300;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end else if(dis < 40)begin
                    simu_x_pos = 0;
                    simu_x_neg = 150;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end else begin 
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end
            end
        end else begin
            if(self_info.y >= LINE_Y)begin
                dis = self_info.y - LINE_Y;
                if(dis < 20)begin
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 300;
                    simu_y_neg = 0;
                end else if(dis < 40)begin
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 150;
                    simu_y_neg = 0;
                end else begin 
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end
            end else begin
                dis = LINE_Y - self_info.y;
                if(dis < 20)begin
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 300;
                end else if(dis < 40)begin
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 150;
                end else begin 
                    simu_x_pos = 0;
                    simu_x_neg = 0;
                    simu_y_pos = 0;
                    simu_y_neg = 0;
                end
            end
        end
    end
    


endmodule