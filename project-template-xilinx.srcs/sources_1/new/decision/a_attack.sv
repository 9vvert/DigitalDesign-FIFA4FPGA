import field_package::*;
module a_attack
#(parameter TEAM=0)
(
    input PlayerInfo self_info,
    output [2:0] force_level,       // 外界的受排斥等级 这种情况下应该为5级
    output [31:0] attack_x_pos,
    output [31:0] attack_x_neg,
    output [31:0] attack_y_pos,
    output [31:0] attack_y_neg
);
    assign force_level = 5;     //使用最高等级的斥力，增大敏感度
    always_comb begin
        //y
        if(self_info.y > LEFT_ATTACK_Y2)begin
            attack_y_pos = 0;
            attack_y_neg = 200;
        end else if(self_info.y < LEFT_ATTACK_Y1)begin
            attack_y_pos = 200;
            attack_y_neg = 0;
        end else begin
            attack_y_pos = 0;
            attack_y_neg = 0;
        end
        
        //x
        if(TEAM==0)begin
            if(self_info.x < RIGHT_ATTACK_X1)begin
                attack_x_pos = 200;
                attack_x_neg = 0;
            end else begin
                attack_x_pos = 0;
                attack_x_neg = 0;
            end
        end else begin
            if(self_info.x > LEFT_ATTACK_X2)begin
                attack_x_pos = 0;
                attack_x_neg = 200;
            end else begin
                attack_x_pos = 0;
                attack_x_neg = 0;
            end
        end
    end


endmodule