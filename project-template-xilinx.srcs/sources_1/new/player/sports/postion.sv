// 运动时的坐标变换器，2025.5.8  ver 2.0
module position_caculator
// 这些参数制定了能够移动的x,y范围，以及初始的x, y值
#(parameter X_MIN = 0, X_MAX=300, Y_MIN = 0, Y_MAX=240, INIT_X = 0, INIT_Y = 0)
(
    input game_clk,
    input rst,
    
    input [7:0] in_angle,           // 外界的angle和speed可以随时变化，内部会在L1周期的开始同步更新这些数值
    input [7:0] in_speed,

    output reg [15:0] out_x,
    output reg [15:0] out_y,
);
    reg [7:0] angle;
    reg [7:0] speed;
    //整体控制
    reg Turn_Mutex;     // 是否处于一个运动周期中
    //第一层计数，根据速度的0-8划分，决定整体的节奏，实现“控制速度”
    reg [9:0] L1_counter;
    reg [9:0] L1_T;
    //第二层计数，根据x，y方向的具体角度分量决定，实现“平滑过渡”
    
    reg [9:0] L2_counter_1;
    reg [9:0] L2_T_1;
    reg [9:0] L2_counter_2;
    reg [9:0] L2_T_2;

    // 先将角度转化为0-17的范围
    wire [7:0] convert_angle;
    wire [1:0] angle_area;      // 区域，1-4象限分别对应0-3

    // sin方向和cos方向的基础比率，现有的数值为0-12，其中对于0要特殊处理，因此需要额外的标志
    wire L2_flag_1;              // sin方向是否为0，如果为0代表该方向为0
    wire L2_flag_2;              // cos方向
    wire [7:0] sin_rate;
    wire [7:0] cos_rate;

    always_comb begin : 
        if(angle < 18) begin
            convert_angle = angle;
            angle_area = 2'd0;
        end else if(angle < 36) begin
            convert_angle = angle - 8'd18;
            angle_area = 2'd1;
        end else if(angle < 54) begin
            convert_angle = angle - 8'd36;
            angle_area = 2'd2;
        end else begin
            convert_angle = angle - 8'd54;
            angle_area = 2'd3;
        end
    end
    assign sin_rate = sin(convert_angle);
    assign cos_rate = cos(convert_angle);
    assign L2_flag_1 = (sin_rate == 8'd0) ? (1'b0) : (1'b1);
    assign L2_flag_2 = (cos_rate == 8'd0) ? (1'b0) : (1'b1);

    always @(posedge game_clk) begin
        if(rst) begin
            out_x <= INIT_X;
            out_y <= INIT_Y;
            Turn_Mutex <= 1'b0;
            L1_counter <= 10'd0;
            L1_T <= 10'd0;
            L2_counter_1 <= 10'd0;
            L2_counter_2 <= 10'd0;
            L2_T_1 <= 10'd0;
            L2_T_2 <= 10'd0;
            //
        end else begin
            if(Turn_Mutex == 1'b0) begin
                // L1周期第一步：根据更新的angle来确定新一轮的角度
                angle <= in_angle;
                speed <= in_speed;
                
                Turn_Mutex <= 1'b1;     //上锁
                case(speed)
                    1: L1_T <= 10'd840;
                        case(sin_rate)
                            1: L2_T_1=10'd839;
                            2: L2_T_1=10'd419;
                            3: L2_T_1=10'd279;
                            4: L2_T_1=10'd209;
                            5: L2_T_1=10'd167;
                            6: L2_T_1=10'd139;
                            7: L2_T_1=10'd119;
                            8: L2_T_1=10'd104;
                            9: L2_T_1=10'd93;
                            10: L2_T_1=10'd83;
                            11: L2_T_1=10'd76;
                            12: L2_T_1=10'd69;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd839;
                            2: L2_T_2=10'd419;
                            3: L2_T_2=10'd279;
                            4: L2_T_2=10'd209;
                            5: L2_T_2=10'd167;
                            6: L2_T_2=10'd139;
                            7: L2_T_2=10'd119;
                            8: L2_T_2=10'd104;
                            9: L2_T_2=10'd93;
                            10: L2_T_2=10'd83;
                            11: L2_T_2=10'd76;
                            12: L2_T_2=10'd69;
                        endcase
                    2: L1_T <= 10'd420;
                        case(sin_rate)
                            1: L2_T_1=10'd419;
                            2: L2_T_1=10'd209;
                            3: L2_T_1=10'd139;
                            4: L2_T_1=10'd104;
                            5: L2_T_1=10'd83;
                            6: L2_T_1=10'd69;
                            7: L2_T_1=10'd59;
                            8: L2_T_1=10'd52;
                            9: L2_T_1=10'd46;
                            10: L2_T_1=10'd41;
                            11: L2_T_1=10'd38;
                            12: L2_T_1=10'd34;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd419;
                            2: L2_T_2=10'd209;
                            3: L2_T_2=10'd139;
                            4: L2_T_2=10'd104;
                            5: L2_T_2=10'd83;
                            6: L2_T_2=10'd69;
                            7: L2_T_2=10'd59;
                            8: L2_T_2=10'd52;
                            9: L2_T_2=10'd46;
                            10: L2_T_2=10'd41;
                            11: L2_T_2=10'd38;
                            12: L2_T_2=10'd34;
                        endcase
                    3: L1_T <= 10'd280;
                        case(sin_rate)
                            1: L2_T_1=10'd279;
                            2: L2_T_1=10'd139;
                            3: L2_T_1=10'd93;
                            4: L2_T_1=10'd69;
                            5: L2_T_1=10'd55;
                            6: L2_T_1=10'd46;
                            7: L2_T_1=10'd39;
                            8: L2_T_1=10'd34;
                            9: L2_T_1=10'd31;
                            10: L2_T_1=10'd27;
                            11: L2_T_1=10'd25;
                            12: L2_T_1=10'd23;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd279;
                            2: L2_T_2=10'd139;
                            3: L2_T_2=10'd93;
                            4: L2_T_2=10'd69;
                            5: L2_T_2=10'd55;
                            6: L2_T_2=10'd46;
                            7: L2_T_2=10'd39;
                            8: L2_T_2=10'd34;
                            9: L2_T_2=10'd31;
                            10: L2_T_2=10'd27;
                            11: L2_T_2=10'd25;
                            12: L2_T_2=10'd23;
                        endcase
                    4: L1_T <= 10'd210;
                        case(sin_rate)
                            1: L2_T_1=10'd209;
                            2: L2_T_1=10'd104;
                            3: L2_T_1=10'd69;
                            4: L2_T_1=10'd52;
                            5: L2_T_1=10'd41;
                            6: L2_T_1=10'd34;
                            7: L2_T_1=10'd29;
                            8: L2_T_1=10'd26;
                            9: L2_T_1=10'd23;
                            10: L2_T_1=10'd20;
                            11: L2_T_1=10'd19;
                            12: L2_T_1=10'd17;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd209;
                            2: L2_T_2=10'd104;
                            3: L2_T_2=10'd69;
                            4: L2_T_2=10'd52;
                            5: L2_T_2=10'd41;
                            6: L2_T_2=10'd34;
                            7: L2_T_2=10'd29;
                            8: L2_T_2=10'd26;
                            9: L2_T_2=10'd23;
                            10: L2_T_2=10'd20;
                            11: L2_T_2=10'd19;
                            12: L2_T_2=10'd17;
                        endcase
                    5: L1_T <= 10'd168;
                        case(sin_rate)
                            1: L2_T_1=10'd167;
                            2: L2_T_1=10'd83;
                            3: L2_T_1=10'd55;
                            4: L2_T_1=10'd41;
                            5: L2_T_1=10'd33;
                            6: L2_T_1=10'd27;
                            7: L2_T_1=10'd23;
                            8: L2_T_1=10'd20;
                            9: L2_T_1=10'd18;
                            10: L2_T_1=10'd16;
                            11: L2_T_1=10'd15;
                            12: L2_T_1=10'd13;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd167;
                            2: L2_T_2=10'd83;
                            3: L2_T_2=10'd55;
                            4: L2_T_2=10'd41;
                            5: L2_T_2=10'd33;
                            6: L2_T_2=10'd27;
                            7: L2_T_2=10'd23;
                            8: L2_T_2=10'd20;
                            9: L2_T_2=10'd18;
                            10: L2_T_2=10'd16;
                            11: L2_T_2=10'd15;
                            12: L2_T_2=10'd13;
                        endcase
                    6: L1_T <= 10'd140;
                        case(sin_rate)
                            1: L2_T_1=10'd139;
                            2: L2_T_1=10'd69;
                            3: L2_T_1=10'd46;
                            4: L2_T_1=10'd34;
                            5: L2_T_1=10'd27;
                            6: L2_T_1=10'd23;
                            7: L2_T_1=10'd19;
                            8: L2_T_1=10'd17;
                            9: L2_T_1=10'd15;
                            10: L2_T_1=10'd13;
                            11: L2_T_1=10'd12;
                            12: L2_T_1=10'd11;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd139;
                            2: L2_T_2=10'd69;
                            3: L2_T_2=10'd46;
                            4: L2_T_2=10'd34;
                            5: L2_T_2=10'd27;
                            6: L2_T_2=10'd23;
                            7: L2_T_2=10'd19;
                            8: L2_T_2=10'd17;
                            9: L2_T_2=10'd15;
                            10: L2_T_2=10'd13;
                            11: L2_T_2=10'd12;
                            12: L2_T_2=10'd11;
                        endcase
                    7: L1_T <= 10'd120;
                        case(sin_rate)
                            1: L2_T_1=10'd119;
                            2: L2_T_1=10'd59;
                            3: L2_T_1=10'd39;
                            4: L2_T_1=10'd29;
                            5: L2_T_1=10'd23;
                            6: L2_T_1=10'd19;
                            7: L2_T_1=10'd17;
                            8: L2_T_1=10'd14;
                            9: L2_T_1=10'd13;
                            10: L2_T_1=10'd11;
                            11: L2_T_1=10'd10;
                            12: L2_T_1=10'd9;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd119;
                            2: L2_T_2=10'd59;
                            3: L2_T_2=10'd39;
                            4: L2_T_2=10'd29;
                            5: L2_T_2=10'd23;
                            6: L2_T_2=10'd19;
                            7: L2_T_2=10'd17;
                            8: L2_T_2=10'd14;
                            9: L2_T_2=10'd13;
                            10: L2_T_2=10'd11;
                            11: L2_T_2=10'd10;
                            12: L2_T_2=10'd9;
                        endcase
                    8: L1_T <= 10'd105;
                        case(sin_rate)
                            1: L2_T_1=10'd104;
                            2: L2_T_1=10'd52;
                            3: L2_T_1=10'd34;
                            4: L2_T_1=10'd26;
                            5: L2_T_1=10'd20;
                            6: L2_T_1=10'd17;
                            7: L2_T_1=10'd14;
                            8: L2_T_1=10'd13;
                            9: L2_T_1=10'd11;
                            10: L2_T_1=10'd10;
                            11: L2_T_1=10'd9;
                            12: L2_T_1=10'd8;
                        endcase

                        case(cos_rate)
                            1: L2_T_2=10'd104;
                            2: L2_T_2=10'd52;
                            3: L2_T_2=10'd34;
                            4: L2_T_2=10'd26;
                            5: L2_T_2=10'd20;
                            6: L2_T_2=10'd17;
                            7: L2_T_2=10'd14;
                            8: L2_T_2=10'd13;
                            9: L2_T_2=10'd11;
                            10: L2_T_2=10'd10;
                            11: L2_T_2=10'd9;
                            12: L2_T_2=10'd8;
                        endcase
                    default: Turn_Mutex <= 1'b0;      // 速度为0的时候，将刚刚关上的锁再次打开，直接开启下一个移动周期
                endcase
                L1_counter <= 10'd0;    // 清空L1计数器
                L2_counter_1 <= 10'd0;
                L2_counter_2 <= 10'd0;
            end else begin
                if(L1_counter == L1_T - 1) begin
                    L1_counter <= 10'd0;
                    Turn_Mutex <= 1'b0;         // 这一轮结束
                end else begin
                    L1_counter <= L1_counter + 10'd1;
                end
                if(angle_area == 2'd0) begin
                    //第一象限, x+sin, y-cos
                    if(L2_flag_1) begin
                        if(L2_counter_1 == L2_T_1 - 1) begin
                            L2_counter_1 <= 10'd0;
                            if(out_x < X_MAX) begin
                                out_x <= out_x + 1; 
                            end else begin
                                out_x <= X_MAX;
                            end
                        end else begin
                            L2_counter_1 <= L2_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L2_counter_2 == L2_T_2 - 1) begin
                            L2_counter_2 <= 10'd0;
                            if(out_y > Y_MIN) begin
                                out_y <= out_y - 1;
                            end else begin
                                out_y <= Y_MIN;
                            end
                        end else begin
                            L2_counter_2 <= L2_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd1) begin
                    //第二象限，x+cos, y+sin
                    if(L2_flag_1) begin
                        if(L2_counter_1 == L2_T_1 - 1) begin
                            L2_counter_1 <= 10'd0;
                            if(out_y < Y_MAX) begin
                                out_y <= out_y + 1; 
                            end else begin
                                out_y <= Y_MAX;
                            end
                        end else begin
                            L2_counter_1 <= L2_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L2_counter_2 == L2_T_2 - 1) begin
                            L2_counter_2 <= 10'd0;
                            if(out_x < X_MAX) begin
                                out_x <= out_x + 1;
                            end else begin
                                out_x <= X_MAX;
                            end
                        end else begin
                            L2_counter_2 <= L2_counter_2 + 10'd1;
                        end
                    end
                end else if(angle_area == 2'd2) begin
                    //第三象限，x-sin, y+cos
                    if(L2_flag_1) begin
                        if(L2_counter_1 == L2_T_1 - 1) begin
                            L2_counter_1 <= 10'd0;
                            if(out_x > X_MIN) begin
                                out_x <= out_x - 1; 
                            end else begin
                                out_x <= X_MIN;
                            end
                        end else begin
                            L2_counter_1 <= L2_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L2_counter_2 == L2_T_2 - 1) begin
                            L2_counter_2 <= 10'd0;
                            if(out_y < Y_MAX) begin
                                out_y <= out_y + 1;
                            end else begin
                                out_y <= Y_MAX;
                            end
                        end else begin
                            L2_counter_2 <= L2_counter_2 + 10'd1;
                        end
                    end
                end else begin
                    //第四象限，x-cos, y-sin
                    if(L2_flag_1) begin
                        if(L2_counter_1 == L2_T_1 - 1) begin
                            L2_counter_1 <= 10'd0;
                            if(out_y > Y_MIN) begin
                                out_y <= out_y - 1; 
                            end else begin
                                out_y <= Y_MIN;
                            end
                        end else begin
                            L2_counter_1 <= L2_counter_1 + 10'd1;
                        end
                    end
                    if(L2_flag_2) begin
                        if(L2_counter_2 == L2_T_2 - 1) begin
                            L2_counter_2 <= 10'd0;
                            if(out_x > X_MIN) begin
                                out_x <= out_x - 1;
                            end else begin
                                out_x <= X_MIN;
                            end
                        end else begin
                            L2_counter_2 <= L2_counter_2 + 10'd1;
                        end
                    end
                end
            end
        end
    end

endmodule