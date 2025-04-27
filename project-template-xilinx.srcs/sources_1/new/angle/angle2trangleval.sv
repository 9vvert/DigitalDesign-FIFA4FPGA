module angle2trangleval(
    input wire clk,
    input wire [7:0] angle,  // 输入角度
    output reg [11:0] tan_val,  // 正切乘以64
    output reg [11:0] sin_val,  // 正弦乘以256
    output reg [11:0] cos_val,  // 余弦乘以256
);
    // 三角函数值ROM
    reg [7:0] trangle_rom [0:255];

    initial begin
        $readmemh("trangle.hex", trangle_rom);  // 读取三角函数值
    end

    always @(posedge clk) begin
        trangle_val <= trangle_rom[angle];  // 根据输入角度查表获取三角函数值
    end
endmodule