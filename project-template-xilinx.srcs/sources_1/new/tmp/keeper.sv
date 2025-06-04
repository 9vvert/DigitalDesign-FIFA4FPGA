/******** keeper **********/
// 模拟门将操作，而且删除多余的部分
import type_declare::*;
import ai_package::*;
import field_package::*;
module keeper
#(parameter TEAM=0)
(   
    input simulator_game_clk,
    input rst,
    //信息
    input hold,
    input PlayerInfo self_info,
    input BallInfo ball_info,
    //输出模拟值
    output reg [7:0] ai_left_angle,
    output [7:0] ai_right_angle,
    output [7:0] ai_action_cmd

);
   
    assign ai_right_angle = 'hFF;
    assign ai_action_cmd[7:0] = {1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0};

    // 持续抢球
    always_comb begin
        if(TEAM == 0)begin
            if(ball_info.x < MID_X && ball_info.y < LEFT_NET_Y2 && ball_info.y > LEFT_NET_Y1)begin
                if(self_info.y + 20 < ball_info.y)begin
                    ai_left_angle = 0;
                end else if(ball_info.y + 20 < self_info.y)begin
                    ai_left_angle = 36;
                end else begin
                    ai_left_angle = 'hFF;
                end
            end else begin
                ai_left_angle = 'hFF;
            end
        end else begin
            if(ball_info.x > MID_X && ball_info.y < RIGHT_NET_Y2 && ball_info.y > RIGHT_NET_Y1)begin
                if(self_info.y + 20 < ball_info.y)begin
                    ai_left_angle = 0;
                end else if(ball_info.y + 20 < self_info.y)begin
                    ai_left_angle = 36;
                end else begin
                    ai_left_angle = 'hFF;
                end
            end else begin
                ai_left_angle = 'hFF;
            end
        end
    end

    always@(posedge simulator_game_clk)begin
        if(rst)begin
            
        end else begin
            
        end
    end
    
endmodule