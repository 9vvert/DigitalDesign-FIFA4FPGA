// 运动时的坐标变换器，2025.5.8  ver 2.0

// 2025.5.30更新：调整数值，将速度的周期 / 2后使用
import field_package::*;
module position_caculator
// 这些参数制定了能够移动的x,y范围，以及初始的x, y值
//[TODO] 这里和上层的player都有初始化参数的选项，后续可能要进行统一
// 如果这里设置了football标志，有额外的约束
#(parameter X_MIN = 32, X_MAX=1248, Y_MIN = 32, Y_MAX=688, INIT_X = 635, INIT_Y = 335, FOOTBALL = 0)
(
    input game_clk,
    input rst,
    
    input [7:0] in_angle,           // 外界的angle和speed可以随时变化，内部会在L1周期的开始同步更新这些数值
    input [7:0] in_speed,
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

//////////////////////////////约束
    wire[11:0] x_min, x_max, y_min, y_max;
    assign x_max = (FOOTBALL==0) ? X_MAX : 
            ((out_y < LEFT_NET_Y1)||(out_y > LEFT_NET_Y2)) ? RIGHT_X : RIGHT_NET_X2;
    assign x_min = (FOOTBALL==0) ? X_MIN : 
            ((out_y < LEFT_NET_Y1)||(out_y > LEFT_NET_Y2)) ? LEFT_X : LEFT_NET_X1;
    assign y_max = (FOOTBALL==0) ? Y_MAX : 
            ((out_x < LEFT_NET_X2)||(out_x > RIGHT_NET_X1)) ? LEFT_NET_Y2 : TOP_Y;
    assign y_min = (FOOTBALL==0) ? Y_MIN : 
            ((out_x < LEFT_NET_X2)||(out_x > RIGHT_NET_X1)) ? LEFT_NET_Y1 : BOTTOM_Y;

    reg [7:0] angle;            //代表在一个计数周期中有效的数值
    reg [7:0] speed;
    
    reg [9:0] L_counter_1;
    wire [9:0] LT_1;
    reg [9:0] L_counter_2;
    wire [9:0] LT_2;



    // 先将角度转化为0-17的范围
    reg [7:0] convert_angle;
    reg [1:0] angle_area;      // 区域，1-4象限分别对应0-3
    // sin方向和cos方向的基础比率，现有的数值为0-12，其中对于0要特殊处理，因此需要额外的标志
    reg L2_flag_1;              // sin方向是否为0，如果为0代表该方向为0
    reg L2_flag_2;              // cos方向
    reg [7:0] sin_rate;
    reg [7:0] cos_rate;

    always_comb begin
        convert_angle = (angle < 18) ? angle :
                (angle < 36) ? (angle - 8'd18) :
                (angle < 54) ? (angle - 8'd36) :
                (angle - 8'd54);
        angle_area = (angle < 18) ? 2'd0 :
                        (angle < 36) ? 2'd1 :
                        (angle < 54) ? 2'd2 :
                        2'd3;
        sin_rate = sin(convert_angle);
        cos_rate = cos(convert_angle);
        L2_flag_1 = (sin_rate == 8'd0) ? (1'b0) : (1'b1);
        L2_flag_2 = (cos_rate == 8'd0) ? (1'b0) : (1'b1);
        // case似乎不能嵌套
    end

    sin_table_rom u_sin_rom (
        .clk(game_clk),
        .speed(speed),
        .sin_rate(sin_rate),
        .sin_val(LT_1)
    );
    cos_table_rom u_cos_rom (
        .clk(game_clk),
        .speed(speed),
        .cos_rate(cos_rate),
        .cos_val(LT_2)
    );


    //[TODO] 在这里发现了极其危险的信号竞争情况！
    //如果在同一个时钟周期中，x信号可能改变，而且还要使用x信号引起连锁的y信号，会出现问题
    //对于reg类型，可以用阻塞赋值来保证安全，但是对于wire则不然，可以延时一个周期让信号稳定

    reg [1:0] pos_cal_stat;
    localparam [1:0] IDLE=0,COUNT=1;
    always @(posedge game_clk) begin
        if(rst) begin
            out_x <= INIT_X;
            out_y <= INIT_Y;
            // 水平运动部分
            L_counter_1 <= 10'd0;
            L_counter_2 <= 10'd0;
            //[TODO]周期的默认值不要设置成0
            speed <= 8'd0;
            angle <= 8'd0;
            pos_cal_stat <= IDLE;
        end else if(set_pos_enable)begin
            out_x <= set_x_val;
            out_y <= set_y_val;
            pos_cal_stat <= IDLE;
        end else begin
            if(pos_cal_stat == IDLE)begin
                speed <= in_speed;
                angle <= in_angle;
                if(speed > 0)begin
                    pos_cal_stat <= COUNT;
                end
            end else if(pos_cal_stat == COUNT)begin
                if(angle_area == 2'd0) begin
                    //第一象限, x+sin, y+cos
                    if(L2_flag_1) begin
                        if(L_counter_1 >= (LT_1>>1)) begin
                            L_counter_1 <= 10'd0;
                            pos_cal_stat <= IDLE;   //开始新一轮检测
                            if(out_x < x_max) begin
                                out_x <= out_x + 1; 
                            end else begin
                                out_x <= x_max;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 >= (LT_2>>1)) begin
                            L_counter_2 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_y < y_max) begin
                                out_y <= out_y + 1;
                            end else begin
                                out_y <= y_max;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd1) begin
                    //第二象限，x+cos, y-sin
                    if(L2_flag_1) begin
                        if(L_counter_1 >= (LT_1>>1)) begin
                            L_counter_1 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_y > y_min) begin
                                out_y <= out_y - 1; 
                            end else begin
                                out_y <= y_min;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 >= (LT_2>>1)) begin
                            L_counter_2 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_x < x_max) begin
                                out_x <= out_x + 1;
                            end else begin
                                out_x <= x_max;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd2) begin
                    //第三象限，x-sin, y-cos
                    if(L2_flag_1) begin
                        if(L_counter_1 >= (LT_1>>1)) begin
                            L_counter_1 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_x > x_min) begin
                                out_x <= out_x - 1; 
                            end else begin
                                out_x <= x_min;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 >= (LT_2>>1)) begin
                            L_counter_2 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_y > y_min) begin
                                out_y <= out_y - 1;
                            end else begin
                                out_y <= y_min;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end else begin
                    //第四象限，x-cos, y+sin
                    if(L2_flag_1) begin
                        if(L_counter_1 >= (LT_1>>1)) begin
                            L_counter_1 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_y < y_max) begin
                                out_y <= out_y + 1; 
                            end else begin
                                out_y <= y_max;
                            end
                        end else begin
                            L_counter_1 <= L_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L_counter_2 >= (LT_2>>1)) begin
                            L_counter_2 <= 10'd0;
                            pos_cal_stat <= IDLE;
                            if(out_x > x_min) begin
                                out_x <= out_x - 1;
                            end else begin
                                out_x <= x_min;
                            end
                        end else begin
                            L_counter_2 <= L_counter_2 + 10'd1;
                        end
                    end
                end
            end
        end
    end

    
endmodule