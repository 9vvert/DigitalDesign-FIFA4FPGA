// 进攻方的保底

module a_defend
#(parameter TEAM=0)    
(
    input PlayerInfo self_info,
    input PlayerInfo arival_info1,      // 排除了门将
    input PlayerInfo arival_info2,
    input PlayerInfo arival_info3,
    input PlayerInfo arival_info4,
    output [2:0] force_level,       // 外界的受排斥等级 这种情况下应该为5级
    output reg sprint_enable,
    output reg[31:0] defend_x_pos,
    output reg[31:0] defend_x_neg,
    output reg[31:0] defend_y_pos,
    output reg[31:0] defend_y_neg
);
    logic [11:0] last_x;
    logic [11:0] last_y;
    assign force_level = 3;
    always_comb begin
        // 选择水平方向最靠后的人, +/-150的矩形区域
        if((arival_info1.x <= arival_info2.x)&&(arival_info1.x <= arival_info3.x)&&(arival_info1.x <= arival_info4.x))begin
            last_x = arival_info1.x;
            last_y = arival_info1.y;
        end else if((arival_info2.x <= arival_info1.x)&&(arival_info2.x <= arival_info3.x)&&(arival_info2.x <= arival_info4.x))begin
            last_x = arival_info2.x;
            last_y = arival_info2.y;
        end else if((arival_info3.x <= arival_info1.x)&&(arival_info3.x <= arival_info2.x)&&(arival_info3.x <= arival_info4.x))begin
            last_x = arival_info3.x;
            last_y = arival_info3.y;
        end else begin
            last_x = arival_info4.x;
            last_y = arival_info4.y;
        end
    end

    always_comb begin
        if(TEAM==0)begin
            if(self_info.x + 200 < last_x) begin
                sprint_enable = 1;    
            end else begin
                sprint_enable = 0;
            end
        end else begin
            if(last_x + 200 < self_info.x) begin
                sprint_enable = 1;    
            end else begin
                sprint_enable = 0;
            end
        end
    end
        // 水平方向上，整体移动
    always_comb begin
        /******水平方向的力  ******/
        if(TEAM==0)begin 
            if(last_x > self_info.x + 150)begin
                defend_x_pos = 150;
                defend_x_neg = 0;
            end else if(last_x + 150 < self_info.x)begin
                defend_x_pos = 0;
                defend_x_neg = 150;
            end else begin
                defend_x_pos = 0;
                defend_x_neg = 0;
            end
        end else begin
            if(self_info.x  > last_x + 150)begin
                defend_x_pos = 0;
                defend_x_neg = 150;
            end else if(self_info.x + 150 < last_x)begin
                defend_x_pos = 150;
                defend_x_neg = 0;
            end else begin
                defend_x_pos = 0;
                defend_x_neg = 0;
            end
        end

        /******* 竖直方向的力*******/
        if(last_y + 150 < self_info.y)begin
            defend_y_pos = 0;
            defend_y_neg = 150;
        end else if(self_info.y + 150 < last_y)begin
            defend_y_pos = 150;
            defend_y_neg = 0;
        end else begin
            defend_y_pos = 0;
            defend_y_neg = 0;
        end
    end


endmodule