// 当进入球门前的矩形时，尝试进行射门
// 简化：只要进入这个状态，就进行射门
// 先不考虑其它拦截者，只看门将
import type_declare::*;
import field_package::*;
module a_shoot
#(parameter TEAM=0)
(
    input ai_game_clk,
    input rst,
    input enable,       // 设计时序，不能随意开始，需要增加一个使能
    input self_hold,        // 自己是否持球
    PlayerInfo keeper_info,     // 门将数据
    PlayerInfo self_info,       // 自己的数据
    input [2:0] shoot_level,
    output [2:0] force_level,
    output [11:0] shoot_x_pos,
    output [11:0] shoot_x_neg,
    output [11:0] shoot_y_pos,
    output [11:0] shoot_y_neg,
    output reg ground_shoot             // 射门时，只使用ground_shoot
    
);
    assign force_level = 5;
    import TrianblevalLib::*;
    import AngleLib::*;
    logic [7:0] goal_top_angle;
    logic [7:0] goal_bottom_angle;
    logic [7:0] block_top_angle;
    logic [7:0] block_bottom_angle;
    logic [7:0] aim_angle;
    always_comb begin
        block_top_angle = vec2angle(self_info.x, self_info.y, keeper_info.x, keeper_info.y+20);
        block_bottom_angle = vec2angle(self_info.x, self_info.y, keeper_info.x, keeper_info.y-20);
        if(TEAM==0)begin
            goal_top_angle = vec2angle(self_info.x, self_info.y, RIGHT_NET_X1, RIGHT_NET_Y2);
            goal_bottom_angle = vec2angle(self_info.x, self_info.y, RIGHT_NET_X1, RIGHT_NET_Y1);
            if(block_top_angle <= goal_top_angle)begin  //上方堵死
                aim_angle = (goal_bottom_angle + block_bottom_angle)>>1;
            end else if(block_bottom_angle >= goal_bottom_angle)begin   //下方堵死
                aim_angle = (top_angle + block_top_angle)>>1;
            end else begin
                if(block_top_angle - goal_top_angle >= goal_bottom_angle - block_bottom_angle)begin
                    aim_angle = (top_angle + block_top_angle)>>1;
                end else begin
                    aim_angle = (goal_bottom_angle + block_bottom_angle)>>1;
                end
            end
        end else begin
            goal_top_angle = vec2angle(self_info.x, self_info.y, LEFT_NET_X2, LEFT_NET_Y2);
            goal_bottom_angle = vec2angle(self_info.x, self_info.y, LEFT_NET_X2, LEFT_NET_Y1);
            if(block_top_angle >= goal_top_angle)begin  //上方堵死
                aim_angle = (goal_bottom_angle + block_bottom_angle)>>1;
            end else if(block_bottom_angle <= goal_bottom_angle)begin   //下方堵死
                aim_angle = (top_angle + block_top_angle)>>1;
            end else begin
                if( goal_top_angle-block_top_angle >= block_bottom_angle-goal_bottom_angle)begin
                    aim_angle = (top_angle + block_top_angle)>>1;
                end else begin
                    aim_angle = (goal_bottom_angle + block_bottom_angle)>>1;
                end
            end
        end
    end

    logic [7:0] aim_rel_angle;
    always_comb begin
        aim_rel_angle = rel_angle_val(self_info.angle, aim_angle);
    end

    // 转向力
    always_comb begin
        if(aim_angle < 8'd18) begin
            shoot_x_pos = 30*sin(aim_angle);
            shoot_x_neg  =0;
            shoot_y_pos = 30*cos(aim_angle);
            shoot_y_neg = 0;
        end else if(aim_angle < 8'd36) begin
            shoot_x_pos = 30*cos(aim_angle - 8'd18);
            shoot_x_neg = 0;
            shoot_y_pos = 0;
            shoot_y_neg = 30*sin(aim_angle - 8'd18);
        end else if(aim_angle < 8'd54) begin
            shoot_x_pos = 0;
            shoot_x_neg = 30*sin(aim_angle - 8'd36);
            shoot_y_pos = 0;
            shoot_y_neg = 30*cos(aim_angle - 8'd36);
        end else begin
            shoot_x_pos = 0;
            shoot_x_neg = 30*cos(aim_angle - 8'd54);
            shoot_y_pos = 30*sin(aim_angle - 8'd54);
            shoot_y_neg = 0;
        end
    end

    reg [2:0] a_shoot_stat;
    reg [7:0] aim_rel_angle1;       //增加一级缓冲
    reg [5:0] delay_counter;    //超时释放
    localparam [2:0] IDLE=0, WAIT=1, SHOOT=2, DONE=3;
    always@(posedge ai_game_clk)begin
        if(rst)begin
            a_shoot_stat <= IDLE;
            ground_shoot <= 0;
            delay_counter <= 0;
        end else begin
            aim_rel_angle1 <= aim_rel_angle;
            if(a_shoot_stat == IDLE)begin
                ground_shoot <= 0;
                if(enable && self_hold)begin
                    a_shoot_stat <= WAIT;
                end
            end else if(a_shoot_stat == WAIT)begin
                //蓄力并且调整方向
                ground_shoot <= 1;  // 至少蓄力到4级
                if(shoot_level>=4 && aim_rel_angle1 < 4)begin
                    a_shoot_stat <= SHOOT;
                end
            end else if(a_shoot_stat == SHOOT)begin
                ground_shoot <= 0;
                a_shoot_stat <= DONE;
            end else begin
                if(~self_hold)begin
                    a_shoot_stat <= IDLE;
                end else begin
                    if(delay_counter >= 40)begin
                        delay_counter <= 0;
                        a_shoot_stat <= IDLE;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end 
                end
            end
        end
    end
endmodule