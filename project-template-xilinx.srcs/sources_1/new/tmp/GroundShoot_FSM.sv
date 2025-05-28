// 只有持球人才能进行
module GroundShoot_FSM
// 5个挡位，速度分别为2,3,4,5,6
#(parameter SPEED_MIN=2, SPEED_MAX = 6, CHARG_T = 100)   //实际倍率 * 3
(
    input GroundShoot_FSM_game_clk,
    input rst,
    input hold,     //当前是否持球
    input gnd_shoot_cmd,    //为高电平开始，低电平退出
    //
    output reg GroundShoot_FSM_done,
    output reg [7:0]gnd_shoot_speed,  //输出
    output reg [1:0] GroundShoot_FSM_message        //1成功，2失败
);

import AngleLib::*;
import TrianglevalLib::*;
import LineLib::*;
    /**************************************/
    //DIS_JUDGE: 距离判定。不论何时，一旦距离超过，就会导致状态机结束，返回失败
    //ANG_JUDGE: 角度判定，重点是“人和球连线的角度”和
    localparam IDLE = 6'd0, CHECK_HOLDER = 6'd1, CHECK_CMD = 6'd2, 
        COUNT = 6'd3, SHOOT = 6'd4, DONE = 6'd5;

    reg [5:0] GroundShoot_FSM_stat;
    reg [9:0] charge_counter;

    always@(posedge GroundShoot_FSM_game_clk) begin
        if(rst) begin
            GroundShoot_FSM_stat <= IDLE;
            GroundShoot_FSM_done <= 1'b0;
            gnd_shoot_speed <= SPEED_MIN
            GroundShoot_FSM_message <= 4'd0;    
            charge_counter <= 10'd0;
        end else begin
            if(GroundShoot_FSM_stat == IDLE)begin
                if(gnd_shoot_cmd)begin      //是否可能抖动？以防万一进行一定的计数
                    charge_counter <= 10'd0;
                    GroundShoot_FSM_stat <= CHECK_HOLDER;
                end else begin
                    GroundShoot_FSM_stat <= IDLE;
                end
            end else if(GroundShoot_FSM_stat == CHECK_HOLDER)begin
                if(hold)begin
                    GroundShoot_FSM_stat <= CHECK_CMD;
                end else begin
                    GroundShoot_FSM_message <= 2'd2;
                    GroundShoot_FSM_stat <= DONE;
                end
            end else if(GroundShoot_FSM_stat == CHECK_CMD)begin
                if(gnd_shoot_cmd)begin
                    GroundShoot_FSM_stat <= COUNT;
                end else begin
                    GroundShoot_FSM_stat <= SHOOT;
                end
            end else if(GroundShoot_FSM_stat == COUNT)begin
                if(charge_counter == CHARG_T -1)begin
                    if(gnd_shoot_speed < SPEED_MAX)begin
                        gnd_shoot_speed <= gnd_shoot_speed + 8'd1;
                    end
                    charge_counter <= 10'd0;
                end else begin
                    charge_counter <= charge_counter + 10'd1;
                end
            end else if(GroundShoot_FSM_stat == SHOOT)begin
                //后续会添加动画状态机
                GroundShoot_FSM_message <= 2'd1;    //成功
                GroundShoot_FSM_stat <= DONE;
                GroundShoot_FSM_done <= 1'b1;       //拉高一个周期
            end else if(GroundShoot_FSM_stat == DONE)begin
                GroundShoot_FSM_done <= 1'b0;
                GroundShoot_FSM_stat <= IDLE;
            end else begin
                GroundShoot_FSM_stat <= IDLE;
            end
        end
    end

endmodule