// 运动时的坐标变换器，2025.5.8  ver 2.0
module position_caculator_copy
// 这些参数制定了能够移动的x,y范围，以及初始的x, y值
//[TODO] 这里和上层的player都有初始化参数的选项，后续可能要进行统一
#(parameter X_MIN = 32, X_MAX=1248, Y_MIN = 32, Y_MAX=688, INIT_X = 128, INIT_Y = 128)
(
    input game_clk,
    input rst,
    
    input [7:0] in_angle,           // 外界的angle和speed可以随时变化，内部会在L1周期的开始同步更新这些数值
    input [7:0] in_speed,
    input [7:0] in_vertical_speed,     // z方向速度
    input in_vertical_signal,          // 0向上，1向下
    output reg [11:0] out_x,
    output reg [11:0] out_y,
    // 扩展参数，可以指定位置
    // 外界设置的时候，将set_pos_enable置为高电平，同时给出set_*_val的值，持续2个game_clk周期
    // [TODO]当扩展一个模块的功能时，再检查以前用过这个模块的地方，不要遗漏input
    input set_pos_enable,
    input [11:0] set_x_val,
    input [11:0] set_y_val
);
import AngleLib::*;
import TrianglevalLib::*;
    reg [7:0] angle;
    reg [7:0] speed;
    reg [7:0] last_angle;
    reg [7:0] last_speed;
    
    reg [9:0] L_counter_1;
    reg [9:0] LT_1;
    reg [9:0] L_counter_2;
    reg [9:0] LT_2;

    // 先将角度转化为0-17的范围
    reg [7:0] convert_angle;
    wire [1:0] angle_area;      // 区域，1-4象限分别对应0-3

    // sin方向和cos方向的基础比率，现有的数值为0-12，其中对于0要特殊处理，因此需要额外的标志
    reg L2_flag_1;              // sin方向是否为0，如果为0代表该方向为0
    reg L2_flag_2;              // cos方向
    reg [7:0] sin_rate;
    reg [7:0] cos_rate;

    assign angle_area = (angle < 18) ? 2'd0 :
                        (angle < 36) ? 2'd1 :
                        (angle < 54) ? 2'd2 :
                        2'd3;
    

    //[TODO] 在这里发现了极其危险的信号竞争情况！
    //如果在同一个时钟周期中，x信号可能改变，而且还要使用x信号引起连锁的y信号，会出现问题
    //对于reg类型，可以用阻塞赋值来保证安全，但是对于wire则不然，可以延时一个周期让信号稳定

    always @(posedge game_clk) begin
        if(rst) begin
            last_angle = 8'hEE; //不可能取到的特殊值
            last_speed = 8'hEE;
            out_x <= INIT_X;
            out_y <= INIT_Y;
            // 水平运动部分
            L_counter_1 <= 10'd0;
            L_counter_2 <= 10'd0;
            //[TODO]周期的默认值不要设置成0
            LT_1 <= 10'd999;
            LT_2 <= 10'd999;
            speed <= 8'd0;
            angle <= 8'd0;
        end else if(set_pos_enable)begin
            out_x = set_x_val;
            out_y = set_y_val;
        end else begin
            //对于z方向，不用考虑角度，比较简单
            if( (last_angle != in_angle) || (last_speed != in_speed) ) begin
                angle <= in_angle;
                speed <= in_speed;
                last_angle <= angle;
                last_speed <= speed;
                //[TODO] 这里进行了修改，原本有阻塞赋值和非阻塞赋值  后续进行代码 重构
                convert_angle = (in_angle < 18) ? in_angle :
                        (in_angle < 36) ? (in_angle - 8'd18) :
                        (in_angle < 54) ? (in_angle - 8'd36) :
                        (in_angle - 8'd54);
                sin_rate = sin(convert_angle);
                cos_rate = cos(convert_angle);
                L2_flag_1 = (sin_rate == 8'd0) ? (1'b0) : (1'b1);
                L2_flag_2 = (cos_rate == 8'd0) ? (1'b0) : (1'b1);
                // case似乎不能嵌套
                case(speed)
                    1: begin
                            LT_1 = (sin_rate == 1) ? 10'd839 :
                                    (sin_rate == 2) ? 10'd419 :
                                    (sin_rate == 3) ? 10'd279 :
                                    (sin_rate == 4) ? 10'd209 :
                                    (sin_rate == 5) ? 10'd167 :
                                    (sin_rate == 6) ? 10'd139 :
                                    (sin_rate == 7) ? 10'd119 :
                                    (sin_rate == 8) ? 10'd104 :
                                    (sin_rate == 9) ? 10'd93 :
                                    (sin_rate == 10) ? 10'd83 :
                                    (sin_rate == 11) ? 10'd76 :
                                    (sin_rate == 12) ? 10'd69 : 10'd999;  // 默认值
                            LT_2 = (cos_rate == 1) ? 10'd839 :
                                    (cos_rate == 2) ? 10'd419 :
                                    (cos_rate == 3) ? 10'd279 :
                                    (cos_rate == 4) ? 10'd209 :
                                    (cos_rate == 5) ? 10'd167 :
                                    (cos_rate == 6) ? 10'd139 :
                                    (cos_rate == 7) ? 10'd119 :
                                    (cos_rate == 8) ? 10'd104 :
                                    (cos_rate == 9) ? 10'd93 :
                                    (cos_rate == 10) ? 10'd83 :
                                    (cos_rate == 11) ? 10'd76 :
                                    (cos_rate == 12) ? 10'd69 : 10'd999;
                        end
                    2: begin
                            LT_1 = (sin_rate == 1) ? 10'd419 :
                                    (sin_rate == 2) ? 10'd209 :
                                    (sin_rate == 3) ? 10'd139 :
                                    (sin_rate == 4) ? 10'd104 :
                                    (sin_rate == 5) ? 10'd83 :
                                    (sin_rate == 6) ? 10'd69 :
                                    (sin_rate == 7) ? 10'd59 :
                                    (sin_rate == 8) ? 10'd52 :
                                    (sin_rate == 9) ? 10'd46 :
                                    (sin_rate == 10) ? 10'd41 :
                                    (sin_rate == 11) ? 10'd38 :
                                    (sin_rate == 12) ? 10'd34 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd419 :
                                    (cos_rate == 2) ? 10'd209 :
                                    (cos_rate == 3) ? 10'd139 :
                                    (cos_rate == 4) ? 10'd104 :
                                    (cos_rate == 5) ? 10'd83 :
                                    (cos_rate == 6) ? 10'd69 :
                                    (cos_rate == 7) ? 10'd59 :
                                    (cos_rate == 8) ? 10'd52 :
                                    (cos_rate == 9) ? 10'd46 :
                                    (cos_rate == 10) ? 10'd41 :
                                    (cos_rate == 11) ? 10'd38 :
                                    (cos_rate == 12) ? 10'd34 : 10'd999;
                        end
                    3: begin
                            LT_1 = (sin_rate == 1) ? 10'd279 :
                                    (sin_rate == 2) ? 10'd139 :
                                    (sin_rate == 3) ? 10'd93 :
                                    (sin_rate == 4) ? 10'd69 :
                                    (sin_rate == 5) ? 10'd55 :
                                    (sin_rate == 6) ? 10'd46 :
                                    (sin_rate == 7) ? 10'd39 :
                                    (sin_rate == 8) ? 10'd34 :
                                    (sin_rate == 9) ? 10'd31 :
                                    (sin_rate == 10) ? 10'd27 :
                                    (sin_rate == 11) ? 10'd25 :
                                    (sin_rate == 12) ? 10'd23 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd279 :
                                    (cos_rate == 2) ? 10'd139 :
                                    (cos_rate == 3) ? 10'd93 :
                                    (cos_rate == 4) ? 10'd69 :
                                    (cos_rate == 5) ? 10'd55 :
                                    (cos_rate == 6) ? 10'd46 :
                                    (cos_rate == 7) ? 10'd39 :
                                    (cos_rate == 8) ? 10'd34 :
                                    (cos_rate == 9) ? 10'd31 :
                                    (cos_rate == 10) ? 10'd27 :
                                    (cos_rate == 11) ? 10'd25 :
                                    (cos_rate == 12) ? 10'd23 : 10'd999;
                        end
                    4: begin
                            LT_1 = (sin_rate == 1) ? 10'd209 :
                                    (sin_rate == 2) ? 10'd104 :
                                    (sin_rate == 3) ? 10'd69 :
                                    (sin_rate == 4) ? 10'd52 :
                                    (sin_rate == 5) ? 10'd41 :
                                    (sin_rate == 6) ? 10'd34 :
                                    (sin_rate == 7) ? 10'd29 :
                                    (sin_rate == 8) ? 10'd26 :
                                    (sin_rate == 9) ? 10'd23 :
                                    (sin_rate == 10) ? 10'd20 :
                                    (sin_rate == 11) ? 10'd19 :
                                    (sin_rate == 12) ? 10'd17 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd209 :
                                    (cos_rate == 2) ? 10'd104 :
                                    (cos_rate == 3) ? 10'd69 :
                                    (cos_rate == 4) ? 10'd52 :
                                    (cos_rate == 5) ? 10'd41 :
                                    (cos_rate == 6) ? 10'd34 :
                                    (cos_rate == 7) ? 10'd29 :
                                    (cos_rate == 8) ? 10'd26 :
                                    (cos_rate == 9) ? 10'd23 :
                                    (cos_rate == 10) ? 10'd20 :
                                    (cos_rate == 11) ? 10'd19 :
                                    (cos_rate == 12) ? 10'd17 : 10'd999;
                        end
                    5: begin
                            LT_1 = (sin_rate == 1) ? 10'd167 :
                                    (sin_rate == 2) ? 10'd83 :
                                    (sin_rate == 3) ? 10'd55 :
                                    (sin_rate == 4) ? 10'd41 :
                                    (sin_rate == 5) ? 10'd33 :
                                    (sin_rate == 6) ? 10'd27 :
                                    (sin_rate == 7) ? 10'd23 :
                                    (sin_rate == 8) ? 10'd20 :
                                    (sin_rate == 9) ? 10'd18 :
                                    (sin_rate == 10) ? 10'd16 :
                                    (sin_rate == 11) ? 10'd15 :
                                    (sin_rate == 12) ? 10'd13 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd167 :
                                    (cos_rate == 2) ? 10'd83 :
                                    (cos_rate == 3) ? 10'd55 :
                                    (cos_rate == 4) ? 10'd41 :
                                    (cos_rate == 5) ? 10'd33 :
                                    (cos_rate == 6) ? 10'd27 :
                                    (cos_rate == 7) ? 10'd23 :
                                    (cos_rate == 8) ? 10'd20 :
                                    (cos_rate == 9) ? 10'd18 :
                                    (cos_rate == 10) ? 10'd16 :
                                    (cos_rate == 11) ? 10'd15 :
                                    (cos_rate == 12) ? 10'd13 : 10'd999;
                        end
                    6: begin
                            LT_1 = (sin_rate == 1) ? 10'd139 :
                                    (sin_rate == 2) ? 10'd69 :
                                    (sin_rate == 3) ? 10'd46 :
                                    (sin_rate == 4) ? 10'd34 :
                                    (sin_rate == 5) ? 10'd27 :
                                    (sin_rate == 6) ? 10'd23 :
                                    (sin_rate == 7) ? 10'd19 :
                                    (sin_rate == 8) ? 10'd17 :
                                    (sin_rate == 9) ? 10'd15 :
                                    (sin_rate == 10) ? 10'd13 :
                                    (sin_rate == 11) ? 10'd12 :
                                    (sin_rate == 12) ? 10'd11 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd139 :
                                    (cos_rate == 2) ? 10'd69 :
                                    (cos_rate == 3) ? 10'd46 :
                                    (cos_rate == 4) ? 10'd34 :
                                    (cos_rate == 5) ? 10'd27 :
                                    (cos_rate == 6) ? 10'd23 :
                                    (cos_rate == 7) ? 10'd19 :
                                    (cos_rate == 8) ? 10'd17 :
                                    (cos_rate == 9) ? 10'd15 :
                                    (cos_rate == 10) ? 10'd13 :
                                    (cos_rate == 11) ? 10'd12 :
                                    (cos_rate == 12) ? 10'd11 : 10'd999;
                        end
                    7: begin
                            LT_1 = (sin_rate == 1) ? 10'd119 :
                                    (sin_rate == 2) ? 10'd59 :
                                    (sin_rate == 3) ? 10'd39 :
                                    (sin_rate == 4) ? 10'd29 :
                                    (sin_rate == 5) ? 10'd23 :
                                    (sin_rate == 6) ? 10'd19 :
                                    (sin_rate == 7) ? 10'd17 :
                                    (sin_rate == 8) ? 10'd14 :
                                    (sin_rate == 9) ? 10'd13 :
                                    (sin_rate == 10) ? 10'd11 :
                                    (sin_rate == 11) ? 10'd10 :
                                    (sin_rate == 12) ? 10'd9 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd119 :
                                    (cos_rate == 2) ? 10'd59 :
                                    (cos_rate == 3) ? 10'd39 :
                                    (cos_rate == 4) ? 10'd29 :
                                    (cos_rate == 5) ? 10'd23 :
                                    (cos_rate == 6) ? 10'd19 :
                                    (cos_rate == 7) ? 10'd17 :
                                    (cos_rate == 8) ? 10'd14 :
                                    (cos_rate == 9) ? 10'd13 :
                                    (cos_rate == 10) ? 10'd11 :
                                    (cos_rate == 11) ? 10'd10 :
                                    (cos_rate == 12) ? 10'd9 : 10'd999;
                        end
                    8: begin
                            LT_1 = (sin_rate == 1) ? 10'd104 :
                                    (sin_rate == 2) ? 10'd52 :
                                    (sin_rate == 3) ? 10'd34 :
                                    (sin_rate == 4) ? 10'd26 :
                                    (sin_rate == 5) ? 10'd20 :
                                    (sin_rate == 6) ? 10'd17 :
                                    (sin_rate == 7) ? 10'd14 :
                                    (sin_rate == 8) ? 10'd13 :
                                    (sin_rate == 9) ? 10'd11 :
                                    (sin_rate == 10) ? 10'd10 :
                                    (sin_rate == 11) ? 10'd9 :
                                    (sin_rate == 12) ? 10'd8 : 10'd999;
                            LT_2 = (cos_rate == 1) ? 10'd104 :
                                    (cos_rate == 2) ? 10'd52 :
                                    (cos_rate == 3) ? 10'd34 :
                                    (cos_rate == 4) ? 10'd26 :
                                    (cos_rate == 5) ? 10'd20 :
                                    (cos_rate == 6) ? 10'd17 :
                                    (cos_rate == 7) ? 10'd14 :
                                    (cos_rate == 8) ? 10'd13 :
                                    (cos_rate == 9) ? 10'd11 :
                                    (cos_rate == 10) ? 10'd10 :
                                    (cos_rate == 11) ? 10'd9 :
                                    (cos_rate == 12) ? 10'd8 : 10'd999;
                        end
                    default: begin
                        angle <= 8'hDD; // 这里不能用EE了，否则可能导致死锁
                        speed <= 8'h00;
                        end
                endcase
                L_counter_1 <= 10'd0;
                L_counter_2 <= 10'd0;
            end else if(speed > 0)begin
                if(angle_area == 2'd0) begin
                    //第一象限, x+sin, y+cos
                    if(L2_flag_1) begin
                        if(L_counter_1 == LT_1 - 1) begin
                            L_counter_1 <= 10'd0;
                            if(out_x < X_MAX) begin
                                out_x <= out_x + 1; 
                            end else begin
                                out_x <= X_MAX;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 == LT_2 - 1) begin
                            L_counter_2 <= 10'd0;
                            if(out_y < Y_MAX) begin
                                out_y <= out_y + 1;
                            end else begin
                                out_y <= Y_MAX;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd1) begin
                    //第二象限，x+cos, y-sin
                    if(L2_flag_1) begin
                        if(L_counter_1 == LT_1 - 1) begin
                            L_counter_1 <= 10'd0;
                            if(out_y > Y_MIN) begin
                                out_y <= out_y - 1; 
                            end else begin
                                out_y <= Y_MIN;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 == LT_2 - 1) begin
                            L_counter_2 <= 10'd0;
                            if(out_x < X_MAX) begin
                                out_x <= out_x + 1;
                            end else begin
                                out_x <= X_MAX;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd2) begin
                    //第三象限，x-sin, y-cos
                    if(L2_flag_1) begin
                        if(L_counter_1 == LT_1 - 1) begin
                            L_counter_1 <= 10'd0;
                            if(out_x > X_MIN) begin
                                out_x <= out_x - 1; 
                            end else begin
                                out_x <= X_MIN;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 == LT_2 - 1) begin
                            L_counter_2 <= 10'd0;
                            if(out_y > Y_MIN) begin
                                out_y <= out_y - 1;
                            end else begin
                                out_y <= Y_MIN;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else begin
                    //第四象限，x-cos, y+sin
                    if(L2_flag_1) begin
                        if(L_counter_1 == LT_1 - 1) begin
                            L_counter_1 <= 10'd0;
                            if(out_y < Y_MAX) begin
                                out_y <= out_y + 1; 
                            end else begin
                                out_y <= Y_MAX;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 == LT_2 - 1) begin
                            L_counter_2 <= 10'd0;
                            if(out_x > X_MIN) begin
                                out_x <= out_x - 1;
                            end else begin
                                out_x <= X_MIN;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end
            end else begin
                L_counter_1 <= 10'd0;
                L_counter_2 <= 10'd0;
            end
        end
    end

endmodule