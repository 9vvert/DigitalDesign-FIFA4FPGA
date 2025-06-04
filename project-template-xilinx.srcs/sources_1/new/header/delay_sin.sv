module delay_sin_table_rom (
    input  wire        clk,
    input  wire [7:0]  ang,      // 0~17
    output reg  [9:0]  sin_val
);
    // 10位宽，18项
    (* ram_style = "distributed" *)reg [9:0] SIN_TABLE [0:17];

    initial begin
        // SIN_TABLE
        SIN_TABLE[ 0] = 10'd0;   SIN_TABLE[ 1] = 10'd1;   SIN_TABLE[ 2] = 10'd2;   SIN_TABLE[ 3] = 10'd3;
        SIN_TABLE[ 4] = 10'd4;   SIN_TABLE[ 5] = 10'd5;   SIN_TABLE[ 6] = 10'd6;   SIN_TABLE[ 7] = 10'd7;
        SIN_TABLE[ 8] = 10'd8;   SIN_TABLE[ 9] = 10'd8;   SIN_TABLE[10] = 10'd9;   SIN_TABLE[11] = 10'd10;
        SIN_TABLE[12] = 10'd10;  SIN_TABLE[13] = 10'd11;  SIN_TABLE[14] = 10'd11;  SIN_TABLE[15] = 10'd12;
        SIN_TABLE[16] = 10'd12;  SIN_TABLE[17] = 10'd12;
    end

    always @(posedge clk) begin
        sin_val <= SIN_TABLE[ang];
    end

endmodule