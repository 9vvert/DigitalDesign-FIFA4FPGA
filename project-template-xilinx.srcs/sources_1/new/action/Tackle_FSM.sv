module Tackle_FSM
// TOL_DIS: 判定半径, TOL_ANGLE: 判定角度, （不需要判定速度）
import type_declare::PlayerInfo, type_declare::BallInfo;
#(parameter TOL_DIS1 = 40, TOL_DIS2 = 10, TOL_ANGLE = 9)
(
    input Tackle_FSM_game_clk,
    input rst,
    //和上层HFSM模块的通信协议，捕捉上升沿
    input hold,         
    input tackle_enable,            // 连接到外界的cmd上
    output reg tackle_use_follow,       // 是否使用追踪机
    input PlayerInfo self_info,
    input BallInfo ball_info,
    output reg tackle_signal,           //直接连接到上层的tackle_signal
    output reg tackle_done          // 向外界通知动作结束，但是不保证是否成功
);

import AngleLib::*;
import TrianglevalLib::*;
import LineLib::*;

    logic [31:0] curr_distance;       // 人和球的距离
    logic [7:0] rel_angle;          // 人的朝向 和 人与球连线 的夹角
    logic [7:0] line_angle;
    // 球必须在地上才能抢
    always_comb begin
        curr_distance = distance(self_info.x, self_info.y, ball_info.x, ball_info.y);
        line_angle = vec2angle(self_info.x, self_info.y, ball_info.x, ball_info.y);
        rel_angle = rel_angle_val(line_angle, self_info.angle);
    end
    reg [3:0] Tackle_stat;
    reg [3:0] wait_counter;
    reg done_delay_counter;
    localparam [3:0] IDLE=0, FOLLOW=1, WAIT=2, DONE=3;
    always@(posedge Tackle_FSM_game_clk)begin
        if(rst)begin
            Tackle_stat <= IDLE;
            tackle_signal <= 0;
            tackle_done <= 0;
            wait_counter <= 0;
            done_delay_counter<=0;
        end else begin
            if(Tackle_stat == IDLE)begin
                tackle_done <= 0;
                tackle_use_follow <= 0;
                tackle_signal <= 0;
                if(tackle_enable)begin
                    Tackle_stat <= FOLLOW;
                end
            end else if(Tackle_stat == FOLLOW)begin
                if(~tackle_enable)begin
                    //第一种情况，抢断中止
                    tackle_use_follow <= 0;
                    tackle_signal <= 0;
                    Tackle_stat <= DONE;
                end else if(curr_distance > 2500)begin
                    //超过范围，记为失败
                    tackle_use_follow <= 0;
                    tackle_signal <= 0;
                    Tackle_stat <= DONE;
                end else if( curr_distance > 100 || rel_angle > 18) begin
                    //在范围内，但是距离或者角度不合适，需要继续调整
                    tackle_use_follow <= 1;
                    tackle_signal <= 0;
                    Tackle_stat <= FOLLOW;
                end else begin      // 距离和角度都符合要求，抢断成功
                    tackle_use_follow <= 0;
                    tackle_signal <= 1;        //拉高tackle信号
                    Tackle_stat <= WAIT;
                    wait_counter <= 0;      //每次开启WAIT阶段都清空计数器
                end 
            end else if(Tackle_stat == WAIT)begin
                if(hold)begin       // 成功拿到持球权，结束
                    tackle_signal <= 0;
                    Tackle_stat <= DONE;
                end else begin
                    if(wait_counter >= 8)begin
                        //超时，大概率是因为中途被别人抢断
                        tackle_signal <= 0;
                        wait_counter <= 0;
                        Tackle_stat<= DONE;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
            end else begin
                tackle_done <= 1;
                if(done_delay_counter == 0)begin        //延时一个周期释放
                    done_delay_counter <= 1;
                end else begin
                    done_delay_counter <= 0;
                    Tackle_stat <= IDLE;
                end
            end
        end
    end 
endmodule