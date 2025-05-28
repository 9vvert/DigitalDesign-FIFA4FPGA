/***************  一维速度的计算模块 *******************/
// 在一维速度中，抛弃了角度，但是增加了速度的符号
// 仅仅用于垂直方向的速度，因此抛弃输入的signal （恒为重力加速度，方向向下）
module vertical_speed_caculator
#(parameter V_MIN = 0, V_MAX = 8, V_INIT = 0, A_T = 250)
(
    input game_clk,
    input rst,
    input enable,           // 使能端，此刻是否有加速度，如果是1代表此刻有加速度，外界需要通过pos_z ~ 0 来调整
    output reg[7:0] speed,
    output reg speed_signal,    // 0为向上，1为向下
    //扩展
    input set_speed_enable,
    input [7:0] set_speed_val,
    input set_speed_signal
);

    reg [9:0] acceler_counter;
    always@(posedge game_clk) begin
        if(rst) begin
            //
            speed <= V_INIT;
            acceler_counter <= 10'd0;
        end else if(set_speed_enable)begin  // 重置状态，为了新一轮准备，必须将所有的东西进行重置，包括计数器
            speed <= set_speed_val;
            speed_signal <= set_speed_signal;
            acceler_counter <= 10'd0;
        end else begin
            if(enable) begin
                if(acceler_counter == A_T - 1) begin
                    acceler_counter <= 10'd0;
                    if(speed_signal == 1'b0) begin    // 当前速度向上，减速
                        if(speed > 0) begin
                            speed <= speed - 8'd1;
                        end else begin  // speed = 0
                            speed <= 8'd1;
                            speed_signal <= 1'b1;       //速度变为向下
                        end
                    end else begin              // 当前速度向下，加速
                        if(speed < V_MAX) begin
                            speed <= speed + 8'd1;
                        end else begin
                            speed <= speed; // 最多加到速度8
                        end
                    end
                end else begin
                    acceler_counter <= acceler_counter + 10'd1;
                end
            end else begin
                speed <= speed;     // 不能设为0，否则因为z=0而永远无法有初速度
                speed_signal <= speed_signal;
            end   
        end
    end

endmodule