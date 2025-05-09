module angle_caculator

// 人物在任何时候都会有一个朝向，因此不用额外设置“无方向”这种特殊情况
#(parameter INIT_ANGLE = 0, W_T = 12)
(
    input game_clk,
    input rst,
    input enable,
    input signal,       // 0代表顺时针，1代表逆时针

    output [7:0] angle
    
);
    reg [5:0] angle_counter;

    //[TODO]可能存在的潜在问题：如果在一个统计周期内，外界参数突然变化，会导致抖动吗？
    always@(posedge game_clk)begin
        if(rst) begin
            angle_counter <= 6'd0;
            angle <= INIT_ANGLE;
        end else begin
            if(enable) begin
                if(angle_counter == W_T - 1) begin
                    angle_counter <= 6'd0;
                    if(signal) begin    //逆时针
                        if(angle == 8'd0) begin
                            angle <= 8'd71;
                        end else begin
                            angle <= angle - 8'd1;
                        end
                    end else begin      //顺时针
                        if(angle == 8'd71) begin
                            angle <= 8'd0;
                        end else begin
                            angle <= angle + 8'd1;
                        end
                    end
                end else begin
                    angle_counter <= angle_counter + 6'd1;
                end
                
            end
        end
    end


endmodule