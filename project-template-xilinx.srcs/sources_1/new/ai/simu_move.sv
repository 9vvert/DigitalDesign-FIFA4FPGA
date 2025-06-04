// 输入向量，模拟摇杆运动
module simu_move(
    input simulator_game_clk,
    input rst,
    input [7:0] curr_angle,         //当前自己的角度
    input [11:0] x_pos,
    input [11:0] x_neg,
    input [11:0] y_pos,
    input [11:0] y_neg,
    input enable_sprint,            //是否允许冲刺，某些需要精细调控的状态需要在距离目标近距离的时候禁用冲刺
    output reg simu_sprint,                 //是否使用加速键
    output reg [7:0] simu_left_angle
);
    import TrianglevalLib::*, AngleLib::*;
    logic [7:0] rel_angle;


    reg [3:0] cal_stat;
    localparam[3:0] JUDGE=0, C1=1, C2=2, C3=3, CAL_1=4, CAL_2=5;
    always@(posedge simulator_game_clk)begin
        if(rst)begin
            cal_stat <= JUDGE;
        end else begin
            case(cal_stat)
                JUDGE:begin
                    cal_stat <= (x_pos > x_neg) ? C1 :
                                (x_pos < x_neg) ? C2 :
                                C3;
                end
                C1:begin
                    if(y_pos > y_neg)begin
                        simu_left_angle <= vec2angle(0, 0, x_pos-x_neg, y_pos-y_neg);
                    end else if(y_pos < y_neg)begin
                        simu_left_angle <= vec2angle(0, y_neg-y_pos, x_pos-x_neg, 0);
                    end else begin
                        simu_left_angle <= 18;
                    end
                    cal_stat <= CAL_1;
                end
                C2:begin
                    if(y_pos > y_neg)begin
                        simu_left_angle <= vec2angle(x_neg-x_pos, 0, 0, y_pos-y_neg);
                    end else if(y_pos < y_neg)begin
                        simu_left_angle <= vec2angle(x_neg-x_pos, y_neg-y_pos, 0, 0);
                    end else begin
                        simu_left_angle <= 54;
                    end
                    cal_stat <= CAL_1;
                end
                C3:begin
                    if(y_pos > y_neg)begin
                        simu_left_angle <= 0;
                    end else if(y_pos < y_neg)begin
                        simu_left_angle <= 36;
                    end else begin
                        simu_left_angle <= 'hF;
                    end
                    cal_stat <= CAL_1;
                end
                CAL_1:begin
                    rel_angle <= rel_angle_val(curr_angle, simu_left_angle);
                    cal_stat <= CAL_2;
                end
                CAL_2:begin
                    if(enable_sprint && (rel_angle < 4) )begin
                        //只有当外界允许冲刺，而且和目标角度相差较小的时候，才能使用冲刺键
                        simu_sprint<=1;
                    end else begin
                        simu_sprint<=0;
                    end
                    cal_stat <= JUDGE;
                end
            endcase
        end
    end

endmodule