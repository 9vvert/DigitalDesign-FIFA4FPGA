module speed_caculator
#(parameter V_MIN = 0, V_MAX = 8, V_INIT = 0, A_T = 125)
(
    input game_clk,
    input rst,
    input enable,           // 使能端，此刻是否有加速度，如果是1代表此刻有加速度
    input signal            // 0为正号，1为负号
    output reg[7:0] speed;
);
    reg [9:0] acceler_counter;
    always@(posedge game_clk) begin
        if(rst) begin
            //
            speed <= V_INIT;
            acceler_counter <= 10'd0;
        end else begin
            if(enable) begin
                if(acceler_counter == A_T - 1) begin
                    acceler_counter <= 10'd0;
                    if(signal == 1'b0) begin    // 正号
                        if(speed < V_MAX) begin
                            speed <= speed + 8'd1;
                        end else begin
                            speed <= speed;
                        end
                    end else begin
                        if(speed > V_MIN) begin
                            speed <= speed - 8'd1;
                        end else begin
                            speed <= speed;
                        end
                    end
                end
            end     
        end
    end

endmodule