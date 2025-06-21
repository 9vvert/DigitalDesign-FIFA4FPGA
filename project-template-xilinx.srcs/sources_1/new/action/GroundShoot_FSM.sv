// 只有持球人才能进行
module GroundShoot_FSM
// 相比于传球，射门没有转向动作
import type_declare::PlayerInfo;
import type_declare::FreeInit;
#(parameter SPEED_MIN=4, SPEED_MAX = 8, CHARG_T = 100)   //实际倍率 * 3
(
    input GroundShoot_FSM_game_clk,
    input rst,
    input hold,     //当前是否持球，一旦没有持球，立刻打断
    input shoot_enable,     // 连接外界的按键
    input PlayerInfo self_info,
    output FreeInit free_init,
    output reg shoot_signal,
    output reg [2:0] shoot_level,       //蓄力等级，用于渲染动画，为0的时候不需要外部渲染动画
    output reg shoot_done
);

import AngleLib::*;
import TrianglevalLib::*;
import LineLib::*;
    /**************************************/
    localparam  [3:0]IDLE=0, ACCUMULATE=1, WAIT=2, DONE=3; 

    reg [3:0] GroundShoot_FSM_stat;
    reg [9:0] accumulate_counter;       // 蓄力计数器
    reg [3:0] wait_counter;
    reg done_delay_counter;
    always@(posedge GroundShoot_FSM_game_clk) begin
        if(rst) begin
            GroundShoot_FSM_stat <= IDLE;
            shoot_done <= 0;
            accumulate_counter <= 0;
            shoot_level <= 0;
            done_delay_counter <= 0;
            shoot_signal <= 0;
            wait_counter <= 0;
            //
            free_init.init_speed <= 0;
            free_init.init_angle <= 0;
            free_init.init_vertical_signal <= 0;
            free_init.init_vertical_speed <= 0;
        end else begin
            if(GroundShoot_FSM_stat == IDLE)begin
                shoot_done <= 0;
                shoot_signal <= 0;
                if(shoot_enable)begin
                    GroundShoot_FSM_stat <= ACCUMULATE;
                    accumulate_counter <= 0;
                    shoot_level <= 1;
                end else begin
                    shoot_level <= 0;
                end
            end else if(GroundShoot_FSM_stat == ACCUMULATE)begin
                if(shoot_enable && hold)begin           // 蓄力
                    if(accumulate_counter >= 400)begin
                        accumulate_counter <= 0;
                        if(shoot_level < 5)begin
                            shoot_level <= shoot_level + 1;
                        end
                    end else begin
                        accumulate_counter <= accumulate_counter + 1;
                    end
                end else if(~shoot_enable && hold)begin     // 结束蓄力，射门
                    shoot_signal <= 1;
                    free_init.init_speed <= SPEED_MIN + shoot_level - 1;
                    free_init.init_angle <= self_info.angle;
                    free_init.init_vertical_signal <= 0;
                    free_init.init_vertical_speed <= 0;
                    wait_counter <= 0;
                    GroundShoot_FSM_stat <= WAIT;
                end else begin  // hold突然变成0，在正常的自动机过程中不会发生，除非有人抢断
                    GroundShoot_FSM_stat <= DONE;   //异常终止
                end
            end else if(GroundShoot_FSM_stat == WAIT)begin
                if(~hold)begin       // 不再持球，可能是成功射出，也可能被拦截。但是不关心结果，最后都会结束
                    shoot_signal <= 0;
                    GroundShoot_FSM_stat <= DONE;
                end else begin
                    if(wait_counter >= 8)begin
                        //超时
                        shoot_signal <= 0;
                        wait_counter <= 0;
                        GroundShoot_FSM_stat<= DONE;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
            end else begin
                shoot_done <= 1;
                if(done_delay_counter == 0)begin        //延时一个周期释放
                    done_delay_counter <= 1;
                end else begin
                    done_delay_counter <= 0;
                    GroundShoot_FSM_stat <= IDLE;
                end
            end
        end
    end
endmodule