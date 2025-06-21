module clk_div_1mhz (
    input  wire clk_in,    // 100MHz 输入时钟
    input  wire rst,       // 同步复位
    output reg  clk_out    // 1MHz 输出时钟
);

    reg [6:0] cnt; 

    always @(posedge clk_in) begin
        if (rst) begin
            cnt     <= 0;
            clk_out <= 0;
        end else begin
            if (cnt == 49) begin
                cnt     <= 0;
                clk_out <= ~clk_out; // 翻转输出
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

endmodule