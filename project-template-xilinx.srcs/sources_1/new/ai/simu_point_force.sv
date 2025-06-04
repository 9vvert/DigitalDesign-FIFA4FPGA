// 模拟力场
import type_declare::*;
// 将obj_info为中心分为5个换，每次R + 20
module simu_point_force(
    input simulator_game_clk,
    input rst,
    input PlayerInfo self_info,
    input PlayerInfo obj_info,
    input [2:0]level,                   // 斥力等级，0代表没有斥力，1-5依次增大
    
    //输出作用力
    output reg [11:0] simu_x_pos,
    output reg [11:0] simu_x_neg,
    output reg [11:0] simu_y_pos,
    output reg [11:0] simu_y_neg
);
    import LineLib::*, TrianglevalLib::*, AngleLib::*;
    logic [7:0] force_angle;
    logic [11:0] dis;
    logic [7:0] force_val;
    logic [7:0] line_angle;


    reg [7:0] ang;
    wire [9:0] sin_val;
    wire [9:0] cos_val;
    delay_sin_table_rom a_rom(
        .clk(simulator_game_clk),
        .ang(ang),
        .sin_val(sin_val)
    );
    delay_cos_table_rom b_rom(
        .clk(simulator_game_clk),
        .ang(ang),
        .cos_val(cos_val)
    );


    reg [2:0] cal_stat;
    localparam[2:0] START=0, CAL_ANGLE=1, LEVEL=2, FORCE=3, ULTI=4;
    // line_angle
    reg [3:0] level_index;
    always@(posedge simulator_game_clk)begin
        if(rst)begin
            level_index <= 5;
            cal_stat<=START;
        end else begin
            case(cal_stat)
                START:begin
                    dis = distance(self_info.x, self_info.y, obj_info.x, obj_info.y);
                    cal_stat <= CAL_ANGLE;
                end
                CAL_ANGLE: begin
                    if(dis == 0)begin
                        line_angle <= self_info.angle;
                    end else begin
                        //计算作用力的角度
                        line_angle <= vec2angle(obj_info.x, obj_info.y, self_info.x, self_info.y);
                    end
                    cal_stat<= LEVEL;
                end
                LEVEL:begin
                    level_index <= (dis > 10000) ? 5 :
                                    (dis > 6400) ? 4 :
                                    (dis > 3600) ? 3:
                                    (dis > 1600) ? 2:
                                    (dis > 400) ? 1:
                                       0;               // 0环的斥力最强
                    cal_stat <= FORCE;
                end
                FORCE:begin
                    if(level_index >= level)begin
                        force_val <= 0;
                    end else begin
                        force_val <= (level - level_index)*(level - level_index);
                    end
                    if(line_angle < 18)begin
                        ang <= line_angle;
                    end else if(line_angle < 8'd36)begin
                        ang <= line_angle-8'd18;
                    end else if(line_angle < 8'd54)begin
                        ang <= line_angle - 8'd36;
                    end else begin
                        ang <= line_angle - 8'd54;
                    end
                    cal_stat <= ULTI;
                end
                ULTI:begin
                    if(line_angle < 8'd18) begin
                        simu_x_pos <= force_val*sin_val;
                        simu_x_neg <= 0;
                        simu_y_pos <= force_val*cos_val;
                        simu_y_neg <= 0;
                    end else if(line_angle < 8'd36) begin
                        simu_x_pos <= force_val*cos_val;
                        simu_x_neg <= 0;
                        simu_y_pos <= 0;
                        simu_y_neg <= force_val*sin_val;
                    end else if(line_angle < 8'd54) begin
                        simu_x_pos <= 0;
                        simu_x_neg <= force_val*sin_val;
                        simu_y_pos <= 0;
                        simu_y_neg <= force_val*cos_val;
                    end else begin
                        simu_x_pos <= 0;
                        simu_x_neg <= force_val*cos_val;
                        simu_y_pos <= force_val*sin_val;
                        simu_y_neg <= 0;
                    end
                    cal_stat <= START;
                end
            endcase
        end
    end
endmodule