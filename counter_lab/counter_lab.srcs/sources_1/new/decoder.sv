module Decoder (
    input [3:0] d,        // 4位输入，表示数字0-9
    output reg [6:0] seg  // 7位输出，表示七段显示器的A-G段
);

always @* begin
    case (d)
        4'b0000: seg = 7'b1111110; // 0
        4'b0001: seg = 7'b0110000; // 1
        4'b0010: seg = 7'b1101101; // 2
        4'b0011: seg = 7'b1111001; // 3
        4'b0100: seg = 7'b0110011; // 4
        4'b0101: seg = 7'b1011011; // 5
        4'b0110: seg = 7'b1011111; // 6
        4'b0111: seg = 7'b1110000; // 7
        4'b1000: seg = 7'b1111111; // 8
        4'b1001: seg = 7'b1111011; // 9
        default: seg = 7'b0000000; // 如果输入不在0-9范围内，默认熄灭显示
    endcase
end

endmodule