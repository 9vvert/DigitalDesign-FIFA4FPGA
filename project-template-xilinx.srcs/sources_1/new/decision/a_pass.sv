// 决策树进行传球决定
// 简化：不进行远端传球，只进行近传
module a_pass(
    input ai_game_clk,
    input rst,
    input enable,
    // 信息
    input PlayerInfo self_info,
    input PlayerInfo teammate_info,     // 传球对象，由上层决定
    input self_hold,
    input [2:0] shoot_level,
    // 输出
    output [11:0] pass_x_pos,
    output [11:0] pass_x_neg,
    output [11:0] pass_y_pos,
    output [11:0] pass_y_neg,
    output [2:0] pass_level,     
    output ground_pass

);
    assign pass_level = 5;
    import TrianblevalLib::*;
    import AngleLib::*;
    
    logic [7:0] aim_angle;
    always_comb begin
        aim_angle = vec2angle(self_info.x, self_info.y, teammate_info.x, teammate_info.y);
    end

    logic [7:0] aim_rel_angle;
    logic [11:0] aim_rel_dis;       // 个人和目标的相对距离，根据距离选择合适的传球方案
    logic fit_dis;      // 距离是否合适，如果
    always_comb begin
        aim_rel_angle = rel_angle_val(self_info.angle, aim_angle);
        if(aim_rel_dis<=5625 && shoot_level >=1)begin
            fit_dis=1;
        end else if(aim_rel_dis <=22500 && shoot_level >=2)begin
            fit_dis=1;
        end else if(aim_rel_dis <=50625 && shoot_level >= 3)begin
            fit_dis=1;
        end else if(aim_rel_dis <=90000 && shoot_level >= 4)begin
            fit_dis=1;
        end else if(aim_rel_dis <= 140625 && shoot_level >=5)begin
            fit_dis=1;
        end else begin
            fit_dis=0;
        end
    end


    // 转向力
    always_comb begin
        if(aim_angle < 8'd18) begin
            pass_x_pos = 30*sin(aim_angle);
            pass_x_neg  =0;
            pass_y_pos = 30*cos(aim_angle);
            pass_y_neg = 0;
        end else if(aim_angle < 8'd36) begin
            pass_x_pos = 30*cos(aim_angle - 8'd18);
            pass_x_neg = 0;
            pass_y_pos = 0;
            pass_y_neg = 30*sin(aim_angle - 8'd18);
        end else if(aim_angle < 8'd54) begin
            pass_x_pos = 0;
            pass_x_neg = 30*sin(aim_angle - 8'd36);
            pass_y_pos = 0;
            pass_y_neg = 30*cos(aim_angle - 8'd36);
        end else begin
            pass_x_pos = 0;
            pass_x_neg = 30*cos(aim_angle - 8'd54);
            pass_y_pos = 30*sin(aim_angle - 8'd54);
            pass_y_neg = 0;
        end
    end

    reg [2:0] a_pass_stat;
    reg [7:0] aim_rel_angle1;       //增加一级缓冲
    reg [5:0] delay_counter;    //超时释放
    localparam [2:0] IDLE=0, WAIT=1, PASS=2, DONE=3;
    always@(posedge ai_game_clk)begin
        if(rst)begin
            a_pass_stat <= IDLE;
            ground_pass <= 0;
            delay_counter <= 0;
        end else begin
            aim_rel_angle1 <= aim_rel_angle;
            if(a_pass_stat == IDLE)begin
                ground_pass <= 0;
                if(enable && self_hold)begin
                    a_pass_stat <= WAIT;
                end
            end else if(a_pass_stat == WAIT)begin
                //蓄力并且调整方向
                ground_pass <= 1;  // 至少蓄力到3级
                if(pass_level>=3 && fit_dis)begin
                    a_pass_stat <= PASS;
                end
            end else if(a_pass_stat == PASS)begin
                ground_pass <= 0;
                a_pass_stat <= DONE;
            end else begin
                if(~self_hold)begin
                    a_pass_stat <= IDLE;
                end else begin
                    if(delay_counter >= 40)begin
                        delay_counter <= 0;
                        a_pass_stat <= IDLE;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end 
                end
            end
        end
    end
endmodule